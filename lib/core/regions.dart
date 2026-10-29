import '../engine/geo.dart';

/// A Nigerian state: where the map starts before a GPS fix, and the
/// neighbourhoods rival names are drawn from.
class NgState {
  const NgState(this.code, this.name, this.center, this.places);

  final String code;
  final String name;

  /// Roughly the capital's city centre.
  final LatLng center;
  final List<String> places;
}

const kStates = <NgState>[
  NgState('AB', 'Abia', LatLng(5.5250, 7.4944), [
    'Aba',
    'Umuahia',
    'Ohafia',
    'Arochukwu',
    'Bende',
    'Isiala',
  ]),
  NgState('AD', 'Adamawa', LatLng(9.2035, 12.4954), [
    'Yola',
    'Jimeta',
    'Mubi',
    'Numan',
    'Ganye',
    'Gombi',
  ]),
  NgState('AK', 'Akwa Ibom', LatLng(5.0377, 7.9128), [
    'Uyo',
    'Eket',
    'Ikot Ekpene',
    'Oron',
    'Abak',
    'Ewet',
  ]),
  NgState('AN', 'Anambra', LatLng(6.2104, 7.0741), [
    'Awka',
    'Onitsha',
    'Nnewi',
    'Ekwulobia',
    'Amawbia',
    'Ihiala',
  ]),
  NgState('BA', 'Bauchi', LatLng(10.3158, 9.8442), [
    'Bauchi',
    'Azare',
    'Misau',
    'Yelwa',
    'Jama\'are',
  ]),
  NgState('BY', 'Bayelsa', LatLng(4.9267, 6.2676), [
    'Yenagoa',
    'Amassoma',
    'Ogbia',
    'Brass',
    'Kaiama',
    'Swali',
  ]),
  NgState('BE', 'Benue', LatLng(7.7322, 8.5391), [
    'Makurdi',
    'Gboko',
    'Otukpo',
    'Wurukum',
    'North Bank',
  ]),
  NgState('BO', 'Borno', LatLng(11.8311, 13.1510), [
    'Maiduguri',
    'Bama',
    'Biu',
    'Gwange',
    'Bulumkutu',
    'Jere',
  ]),
  NgState('CR', 'Cross River', LatLng(4.9757, 8.3417), [
    'Calabar',
    'Ikom',
    'Ogoja',
    'Obudu',
    'Akamkpa',
    'Marian',
  ]),
  NgState('DE', 'Delta', LatLng(6.1981, 6.7285), [
    'Asaba',
    'Warri',
    'Sapele',
    'Ughelli',
    'Agbor',
    'Effurun',
    'Okpanam',
  ]),
  NgState('EB', 'Ebonyi', LatLng(6.3249, 8.1137), [
    'Abakaliki',
    'Afikpo',
    'Onueke',
    'Ezzamgbo',
    'Ishieke',
  ]),
  NgState('ED', 'Edo', LatLng(6.3350, 5.6037), [
    'Benin',
    'Ekpoma',
    'Auchi',
    'Ugbowo',
    'Uselu',
    'Ikpoba',
  ]),
  NgState('EK', 'Ekiti', LatLng(7.6211, 5.2214), [
    'Ado',
    'Ikere',
    'Ijero',
    'Ise',
    'Efon',
    'Oye',
  ]),
  NgState('EN', 'Enugu', LatLng(6.4584, 7.5464), [
    'Enugu',
    'Nsukka',
    'Trans-Ekulu',
    'Ogui',
    'Agbani',
    'Abakpa',
  ]),
  NgState('FC', 'FCT Abuja', LatLng(9.0579, 7.4951), [
    'Wuse',
    'Maitama',
    'Garki',
    'Gwarinpa',
    'Jabi',
    'Kubwa',
    'Asokoro',
    'Lugbe',
  ]),
  NgState('GO', 'Gombe', LatLng(10.2897, 11.1673), [
    'Gombe',
    'Kaltungo',
    'Billiri',
    'Dukku',
    'Tudun Wada',
  ]),
  NgState('IM', 'Imo', LatLng(5.4836, 7.0333), [
    'Owerri',
    'Orlu',
    'Okigwe',
    'Mbaise',
    'Ikenegbu',
    'Nekede',
  ]),
  NgState('JI', 'Jigawa', LatLng(11.7562, 9.3388), [
    'Dutse',
    'Hadejia',
    'Kazaure',
    'Gumel',
    'Birnin Kudu',
  ]),
  NgState('KD', 'Kaduna', LatLng(10.5105, 7.4165), [
    'Kaduna',
    'Zaria',
    'Barnawa',
    'Kafanchan',
    'Malali',
    'Ungwan Rimi',
  ]),
  NgState('KN', 'Kano', LatLng(12.0022, 8.5920), [
    'Sabon Gari',
    'Nassarawa',
    'Fagge',
    'Tarauni',
    'Gyadi-Gyadi',
    'Bompai',
  ]),
  NgState('KT', 'Katsina', LatLng(12.9908, 7.6018), [
    'Katsina',
    'Funtua',
    'Daura',
    'Malumfashi',
    'Kankia',
  ]),
  NgState('KE', 'Kebbi', LatLng(12.4539, 4.1975), [
    'Birnin Kebbi',
    'Argungu',
    'Yauri',
    'Zuru',
    'Jega',
  ]),
  NgState('KO', 'Kogi', LatLng(7.8023, 6.7333), [
    'Lokoja',
    'Okene',
    'Kabba',
    'Idah',
    'Anyigba',
    'Ganaja',
  ]),
  NgState('KW', 'Kwara', LatLng(8.4966, 4.5421), [
    'Ilorin',
    'Offa',
    'Tanke',
    'Fate',
    'Omu-Aran',
    'Jebba',
  ]),
  NgState('LA', 'Lagos', LatLng(6.5244, 3.3792), [
    'Lekki',
    'Yaba',
    'Ikoyi',
    'Surulere',
    'Ikeja',
    'Ajah',
    'Maryland',
    'Gbagada',
    'Oshodi',
    'Festac',
    'Obalende',
    'Ojota',
    'Ogba',
    'Magodo',
    'Bariga',
    'Akoka',
    'Ilupeju',
  ]),
  NgState('NA', 'Nasarawa', LatLng(8.4939, 8.5153), [
    'Lafia',
    'Keffi',
    'Akwanga',
    'Karu',
    'Mararaba',
  ]),
  NgState('NI', 'Niger', LatLng(9.6139, 6.5569), [
    'Minna',
    'Bida',
    'Suleja',
    'Kontagora',
    'Tunga',
    'Bosso',
  ]),
  NgState('OG', 'Ogun', LatLng(7.1475, 3.3619), [
    'Abeokuta',
    'Ijebu-Ode',
    'Sagamu',
    'Ota',
    'Ifo',
    'Sango',
    'Mowe',
  ]),
  NgState('ON', 'Ondo', LatLng(7.2571, 5.2058), [
    'Akure',
    'Ondo',
    'Owo',
    'Ikare',
    'Oba-Ile',
    'Alagbaka',
  ]),
  NgState('OS', 'Osun', LatLng(7.7827, 4.5418), [
    'Osogbo',
    'Ile-Ife',
    'Ilesa',
    'Ede',
    'Iwo',
    'Ikirun',
  ]),
  NgState('OY', 'Oyo', LatLng(7.3775, 3.9470), [
    'Bodija',
    'Mokola',
    'Dugbe',
    'Ogbomoso',
    'Akobo',
    'Challenge',
    'Oyo',
  ]),
  NgState('PL', 'Plateau', LatLng(9.8965, 8.8583), [
    'Jos',
    'Bukuru',
    'Rayfield',
    'Pankshin',
    'Shendam',
  ]),
  NgState('RI', 'Rivers', LatLng(4.8156, 7.0498), [
    'Rumuola',
    'D-Line',
    'Trans-Amadi',
    'Bonny',
    'Eleme',
    'Rumuokoro',
    'Diobu',
  ]),
  NgState('SO', 'Sokoto', LatLng(13.0059, 5.2476), [
    'Sokoto',
    'Wamakko',
    'Tambuwal',
    'Gwadabawa',
    'Illela',
  ]),
  NgState('TA', 'Taraba', LatLng(8.8937, 11.3596), [
    'Jalingo',
    'Wukari',
    'Takum',
    'Bali',
    'Gembu',
    'Zing',
  ]),
  NgState('YO', 'Yobe', LatLng(11.7470, 11.9608), [
    'Damaturu',
    'Potiskum',
    'Gashua',
    'Nguru',
    'Geidam',
  ]),
  NgState('ZA', 'Zamfara', LatLng(12.1628, 6.6614), [
    'Gusau',
    'Kaura Namoda',
    'Talata Mafara',
    'Anka',
    'Tsafe',
  ]),
];

/// Names used before we know your state: well-known places from across
/// the country.
const kNationalPlaces = [
  'Lekki',
  'Yaba',
  'Wuse',
  'Garki',
  'Bodija',
  'Rumuola',
  'Sabon Gari',
  'Ugbowo',
  'Onitsha',
  'Owerri',
  'Calabar',
  'Jos',
  'Ilorin',
  'Abeokuta',
  'Warri',
  'Enugu',
  'Kaduna',
  'Uyo',
  'Akure',
  'Asaba',
];

NgState? stateByCode(String? code) {
  if (code == null) return null;
  for (final s in kStates) {
    if (s.code == code) return s;
  }
  return null;
}

/// The state whose capital is closest to [p], or null outside Nigeria.
///
/// Capital distance is a rough proxy for borders, so near a state line
/// this can pick the neighbour. It's only used for a default, and the
/// player can change it in settings.
NgState? nearestState(LatLng p) {
  // Nigeria's bounding box, with a little slack.
  if (p.lat < 4 || p.lat > 14 || p.lng < 2.6 || p.lng > 14.8) return null;
  NgState? best;
  var bestD = double.infinity;
  for (final s in kStates) {
    final d = Geo.haversine(p, s.center);
    if (d < bestD) {
      bestD = d;
      best = s;
    }
  }
  return best;
}
