package com.example.gamify.news;

import org.springframework.stereotype.Component;
import org.springframework.web.util.HtmlUtils;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.ByteArrayInputStream;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Reads RSS 2.0 items (news sites, Google News) and Atom entries (YouTube channel feeds): title, link,
 * teaser text, image, category, author/publisher and publish time.
 */
@Component
public class RssFeedParser {

    private static final int MAX_SUMMARY_LENGTH = 400;
    private static final Pattern IMG_SRC = Pattern.compile("<img[^>]+src=[\"']([^\"']+)[\"']", Pattern.CASE_INSENSITIVE);
    private static final Pattern TAG = Pattern.compile("<[^>]+>");

    public List<FeedEntry> parse(byte[] xml) throws Exception {
        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        // Feeds are untrusted input: refuse DTDs and external entities (XXE)
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        factory.setExpandEntityReferences(false);
        Document doc = factory.newDocumentBuilder().parse(new ByteArrayInputStream(xml));
        if (doc.getElementsByTagName("item").getLength() == 0 && doc.getElementsByTagName("entry").getLength() > 0) {
            return parseAtom(doc);
        }

        List<FeedEntry> entries = new ArrayList<>();
        NodeList items = doc.getElementsByTagName("item");
        for (int i = 0; i < items.getLength(); i++) {
            Element item = (Element) items.item(i);
            String link = text(item, "link");
            String publisher = clean(text(item, "source"));
            String title = withoutPublisherSuffix(clean(text(item, "title")), publisher);
            OffsetDateTime publishedAt = parseDate(text(item, "pubDate"));
            // Items without these can't be shown or ordered, so skip them
            if (link == null || title == null || publishedAt == null) {
                continue;
            }
            String description = text(item, "description");
            entries.add(new FeedEntry(
                    link.trim(),
                    title,
                    teaser(summarize(description), title),
                    imageUrl(item, description),
                    clean(text(item, "category")),
                    clean(text(item, "dc:creator")),
                    publisher,
                    publishedAt,
                    false
            ));
        }
        return entries;
    }

    // Atom, as used by YouTube: <entry> with <link rel="alternate" href>, <published>, <author><name>,
    // and the thumbnail/description inside <media:group>
    private static List<FeedEntry> parseAtom(Document doc) {
        List<FeedEntry> entries = new ArrayList<>();
        NodeList items = doc.getElementsByTagName("entry");
        for (int i = 0; i < items.getLength(); i++) {
            Element entry = (Element) items.item(i);
            String link = alternateLink(entry);
            String title = clean(text(entry, "title"));
            OffsetDateTime publishedAt = parseIsoDate(text(entry, "published"));
            if (link == null || title == null || publishedAt == null) {
                continue;
            }
            String thumbnail = attribute(entry, "media:thumbnail", "url");
            entries.add(new FeedEntry(
                    link,
                    title,
                    summarize(text(entry, "media:description")),
                    thumbnail,
                    null,
                    null,
                    clean(text(entry, "name")),
                    publishedAt,
                    link.contains("youtube.com/") || link.contains("youtu.be/")
            ));
        }
        return entries;
    }

    private static String alternateLink(Element entry) {
        NodeList links = entry.getElementsByTagName("link");
        for (int i = 0; i < links.getLength(); i++) {
            Element link = (Element) links.item(i);
            String rel = link.getAttribute("rel");
            if ((rel.isBlank() || rel.equals("alternate")) && !link.getAttribute("href").isBlank()) {
                return link.getAttribute("href").trim();
            }
        }
        return null;
    }

    private static String attribute(Element parent, String tag, String name) {
        NodeList nodes = parent.getElementsByTagName(tag);
        if (nodes.getLength() == 0) {
            return null;
        }
        String value = ((Element) nodes.item(0)).getAttribute(name);
        return value.isBlank() ? null : value.trim();
    }

    // Aggregators like Google News append the publisher: "Big news - The Times"
    private static String withoutPublisherSuffix(String title, String publisher) {
        if (title == null || publisher == null) {
            return title;
        }
        String suffix = " - " + publisher;
        return title.endsWith(suffix) ? title.substring(0, title.length() - suffix.length()).trim() : title;
    }

    // Some feeds repeat the headline as the description (Google News); that's not a teaser
    private static String teaser(String summary, String title) {
        if (summary == null || title == null) {
            return summary;
        }
        return summary.startsWith(title) ? null : summary;
    }

    private static String text(Element parent, String tag) {
        NodeList nodes = parent.getElementsByTagName(tag);
        if (nodes.getLength() == 0) {
            return null;
        }
        String value = nodes.item(0).getTextContent();
        return value == null || value.isBlank() ? null : value.trim();
    }

    // Prefer the full-size enclosure; fall back to the first <img> in the description
    private static String imageUrl(Element item, String description) {
        NodeList enclosures = item.getElementsByTagName("enclosure");
        for (int i = 0; i < enclosures.getLength(); i++) {
            Node node = enclosures.item(i);
            Element enclosure = (Element) node;
            String type = enclosure.getAttribute("type");
            String url = enclosure.getAttribute("url");
            if (!url.isBlank() && (type.isBlank() || type.startsWith("image/"))) {
                return url.trim();
            }
        }
        if (description != null) {
            Matcher matcher = IMG_SRC.matcher(description);
            if (matcher.find()) {
                return HtmlUtils.htmlUnescape(matcher.group(1)).trim();
            }
        }
        return null;
    }

    // The description is HTML (image + teaser); keep only the readable text
    private static String summarize(String description) {
        String text = clean(description == null ? null : TAG.matcher(description).replaceAll(" "));
        if (text == null || text.length() <= MAX_SUMMARY_LENGTH) {
            return text;
        }
        return text.substring(0, MAX_SUMMARY_LENGTH).replaceAll("\\s+\\S*$", "") + "…";
    }

    private static String clean(String value) {
        if (value == null) {
            return null;
        }
        String text = HtmlUtils.htmlUnescape(value).replaceAll("\\s+", " ").trim();
        return text.isEmpty() ? null : text;
    }

    private static OffsetDateTime parseIsoDate(String value) {
        if (value == null) {
            return null;
        }
        try {
            return OffsetDateTime.parse(value);
        } catch (DateTimeParseException e) {
            return null;
        }
    }

    private static OffsetDateTime parseDate(String value) {
        if (value == null) {
            return null;
        }
        try {
            return OffsetDateTime.parse(value, DateTimeFormatter.RFC_1123_DATE_TIME);
        } catch (DateTimeParseException e) {
            return null;
        }
    }
}
