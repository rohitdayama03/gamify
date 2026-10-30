// Preset values for the register / edit profile forms
class FormOptions {
  // Country calling codes for the phone number field; India first as most players are there
  static const List<({String country, String code})> dialCodes = [
    (country: 'India', code: '+91'),
    (country: 'Bangladesh', code: '+880'),
    (country: 'Nepal', code: '+977'),
    (country: 'Pakistan', code: '+92'),
    (country: 'Sri Lanka', code: '+94'),
    (country: 'United Arab Emirates', code: '+971'),
    (country: 'Saudi Arabia', code: '+966'),
    (country: 'Singapore', code: '+65'),
    (country: 'Malaysia', code: '+60'),
    (country: 'United Kingdom', code: '+44'),
    (country: 'United States / Canada', code: '+1'),
    (country: 'Australia', code: '+61'),
  ];

  // A player can speak several languages; they are stored as one comma-separated string
  static const int maxLanguages = 5;
  static const String languageSeparator = ', ';

  static List<String> splitLanguages(String? value) => (value ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  static String joinLanguages(List<String> languages) => languages.join(languageSeparator);

  static const List<String> languages = [
    'Arabic', 'Assamese', 'Bengali', 'Bhojpuri', 'Burmese', 'Cantonese', 'Czech', 'Dutch',
    'English', 'Filipino', 'French', 'German', 'Greek', 'Gujarati', 'Hebrew', 'Hindi',
    'Hungarian', 'Indonesian', 'Italian', 'Japanese', 'Kannada', 'Kashmiri', 'Khmer', 'Konkani',
    'Korean', 'Malay', 'Malayalam', 'Mandarin', 'Marathi', 'Nepali', 'Odia', 'Pashto',
    'Persian', 'Polish', 'Portuguese', 'Punjabi', 'Romanian', 'Russian', 'Sanskrit', 'Sindhi',
    'Sinhala', 'Spanish', 'Swahili', 'Swedish', 'Tamil', 'Telugu', 'Thai', 'Turkish',
    'Ukrainian', 'Urdu', 'Vietnamese',
  ];

  static const List<String> countries = [
    'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola', 'Antigua and Barbuda', 'Argentina',
    'Armenia', 'Australia', 'Austria', 'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados',
    'Belarus', 'Belgium', 'Belize', 'Benin', 'Bhutan', 'Bolivia', 'Bosnia and Herzegovina', 'Botswana',
    'Brazil', 'Brunei', 'Bulgaria', 'Burkina Faso', 'Burundi', 'Cambodia', 'Cameroon', 'Canada',
    'Cape Verde', 'Central African Republic', 'Chad', 'Chile', 'China', 'Colombia', 'Comoros',
    'Congo', 'Costa Rica', 'Croatia', 'Cuba', 'Cyprus', 'Czech Republic',
    'Democratic Republic of the Congo', 'Denmark', 'Djibouti', 'Dominica', 'Dominican Republic',
    'Ecuador', 'Egypt', 'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini',
    'Ethiopia', 'Fiji', 'Finland', 'France', 'Gabon', 'Gambia', 'Georgia', 'Germany', 'Ghana',
    'Greece', 'Grenada', 'Guatemala', 'Guinea', 'Guinea-Bissau', 'Guyana', 'Haiti', 'Honduras',
    'Hungary', 'Iceland', 'India', 'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Israel', 'Italy',
    'Ivory Coast', 'Jamaica', 'Japan', 'Jordan', 'Kazakhstan', 'Kenya', 'Kiribati', 'Kuwait',
    'Kyrgyzstan', 'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya', 'Liechtenstein',
    'Lithuania', 'Luxembourg', 'Madagascar', 'Malawi', 'Malaysia', 'Maldives', 'Mali', 'Malta',
    'Marshall Islands', 'Mauritania', 'Mauritius', 'Mexico', 'Micronesia', 'Moldova', 'Monaco',
    'Mongolia', 'Montenegro', 'Morocco', 'Mozambique', 'Myanmar', 'Namibia', 'Nauru', 'Nepal',
    'Netherlands', 'New Zealand', 'Nicaragua', 'Niger', 'Nigeria', 'North Korea', 'North Macedonia',
    'Norway', 'Oman', 'Pakistan', 'Palau', 'Palestine', 'Panama', 'Papua New Guinea', 'Paraguay',
    'Peru', 'Philippines', 'Poland', 'Portugal', 'Qatar', 'Romania', 'Russia', 'Rwanda',
    'Saint Kitts and Nevis', 'Saint Lucia', 'Saint Vincent and the Grenadines', 'Samoa',
    'San Marino', 'Sao Tome and Principe', 'Saudi Arabia', 'Senegal', 'Serbia', 'Seychelles',
    'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia', 'Solomon Islands', 'Somalia',
    'South Africa', 'South Korea', 'South Sudan', 'Spain', 'Sri Lanka', 'Sudan', 'Suriname',
    'Sweden', 'Switzerland', 'Syria', 'Taiwan', 'Tajikistan', 'Tanzania', 'Thailand', 'Timor-Leste',
    'Togo', 'Tonga', 'Trinidad and Tobago', 'Tunisia', 'Turkey', 'Turkmenistan', 'Tuvalu', 'Uganda',
    'Ukraine', 'United Arab Emirates', 'United Kingdom', 'United States', 'Uruguay', 'Uzbekistan',
    'Vanuatu', 'Vatican City', 'Venezuela', 'Vietnam', 'Yemen', 'Zambia', 'Zimbabwe',
  ];
}
