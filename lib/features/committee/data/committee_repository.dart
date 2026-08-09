import '../../../core/network/api_client.dart';

class CommitteeMember {
  const CommitteeMember({
    required this.id,
    required this.name,
    this.post = '',
    this.umoor = '',
    this.phone = '',
    this.email = '',
    this.photo = '',
    this.colorHex = '#3D1035',
  });

  final String id;
  final String name;
  final String post;
  final String umoor;
  final String phone;
  final String email;
  final String photo;
  final String colorHex;

  factory CommitteeMember.fromJson(Map<String, dynamic> json) {
    return CommitteeMember(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}'.trim(),
      post: '${json['post'] ?? ''}'.trim(),
      umoor: '${json['umoor'] ?? ''}'.trim(),
      phone: '${json['phone'] ?? ''}'.trim(),
      email: '${json['email'] ?? ''}'.trim(),
      photo: '${json['photo'] ?? ''}'.trim(),
      colorHex: '${json['color'] ?? '#3D1035'}'.trim(),
    );
  }
}

class CommitteeRepository {
  CommitteeRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();

  final ApiClient _api;

  Future<List<CommitteeMember>> fetchMembers() async {
    try {
      final response = await _api.get(
        'Committee/members',
        style: AuthHeaderStyle.none,
      );
      final parsed = _parse(response);
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {
      // Fall through to bundled Contact Us list.
    }
    return localMembers();
  }

  List<CommitteeMember> _parse(dynamic response) {
    List? raw;
    if (response is List) {
      raw = response;
    } else if (response is Map) {
      final data = response['data'];
      if (data is List) raw = data;
    }
    if (raw == null) return const [];
    return raw
        .whereType<Map>()
        .map((e) => CommitteeMember.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.name.isNotEmpty)
        .toList();
  }

  /// Bundled from website Contact Us (works before API upload).
  static List<CommitteeMember> localMembers() {
    const base = 'https://tmk53.com/uploads/';
    const rows = <Map<String, String>>[
      {
        'name': 'Shaikh Mohammed bhai Shaikh Taherali bhai Petiwala',
        'post': 'Janab Amil Saheb',
        'color': '#809248',
      },
      {
        'name': 'Shaikh Hakimuddin bhai',
        'post': 'Head Moallim saheb',
        'color': '#76bee6',
      },
      {
        'name': 'Shaikh Abbasbhai',
        'post': 'Mahad uz zahra',
        'color': '#ddcb4d',
      },
      {
        'name': 'Shaikh Abbasbhai Lalji',
        'post': 'Vaali Mulla saheb',
        'color': '#d4b13d',
      },
      {
        'name': 'Mulla Murtaza bhai Ismail bhai Mamji',
        'post': 'Joint Treasurer',
        'umoor': 'Umoor Deeniyah',
        'phone': '+96599455394',
        'email': 'alimamji@gmail.com',
        'photo': '${base}mamji.jpg',
        'color': '#809248',
      },
      {
        'name': 'Shaikh Abbas bhai Shaikh Abdullah bhai Joher',
        'post': 'Additional Treasurer',
        'umoor': 'Umoor Talimiyah',
        'phone': '+96599478486',
        'email': 'abbasalijohar@gmail.com',
        'photo': '${base}johar.png',
        'color': '#76bee6',
      },
      {
        'name': 'Mulla Abbas bhai Fakhruddin bhai Gariba',
        'post': 'FMB J. Secretary',
        'umoor': 'Umoor Marafiq Burhaniyah',
        'phone': '+96597299589',
        'email': 'gariba786@hotmail.com',
        'photo': '${base}gariba.png',
        'color': '#ddcb4d',
      },
      {
        'name': 'Shaikh Aliasgar bhai Shaikh Alihusain bhai Tatiwala',
        'post': 'Acting Treasurer',
        'umoor': 'Umoor Maliyah',
        'phone': '+96599010249',
        'email': 'printerprofessionals@gmail.com',
        'photo': '${base}tatiwala.png',
        'color': '#d4b13d',
      },
      {
        'name': 'Shaikh Aliasgar bhai Shaikh Alihusain bhai Tatiwala',
        'post': 'Secretary',
        'umoor': 'Umoor Mawarid Bashariyah',
        'phone': '+96599010249',
        'email': 'printerprofessionals@gmail.com',
        'photo': '${base}tatiwala.png',
        'color': '#f7ae61',
      },
      {
        'name': 'Mulla Abbas bhai Mulla Qutbuddin bhai Pithapurwala',
        'post': 'Member',
        'umoor': 'Umoor Dakheliyah',
        'phone': '+96565998484',
        'email': 'abbasionline@hotmail.com',
        'photo': '${base}pithapur.jpg',
        'color': '#c9a6ce',
      },
      {
        'name': 'Mulla Hakimuddin bhai Shaikh Fakhruddin bhai Khedapa',
        'post': 'FMB Joint Finanace',
        'umoor': 'Umoor Kharejiyah',
        'phone': '+96598808878',
        'email': 'h_khedapa2@hotmail.com',
        'photo': '${base}Khedapa.png',
        'color': '#d78996',
      },
      {
        'name': 'Mulla Hashim bhai Fakhruddin bhai Vardawala',
        'post': 'Member',
        'umoor': 'Umoor Al-Qaza',
        'phone': '+96566366503',
        'email': 'hashim_varda@hotmail.com',
        'photo': '${base}varda.jpg',
        'color': '#cd5b5b',
      },
      {
        'name': 'Shaikh Fakhruddin bhai Mohammed bhai Amulawala',
        'post': 'Member',
        'umoor': 'Umoor Faiz ul Mawaid il Burhaniyah / Niyaaz',
        'phone': '+96595595072',
        'email': 'famulawala@gmail.com',
        'photo': '${base}Amula.jpg',
        'color': '#b38665',
      },
      {
        'name': 'Shaikh Haiderali bhai Shaikh Qutbuddin bhai Lokawala',
        'post': 'Additional Secretary',
        'umoor': 'Umoor Iqtesadiyah',
        'phone': '+96599992786',
        'email': 'haideraliloka@gmail.com',
        'photo': '${base}loka.jpg',
        'color': '#006fc0',
      },
      {
        'name': 'Shaikh Qutbuddin bhai Shaikh Najmuddin bhai Kotawala',
        'post': 'Vice President',
        'umoor': 'Umoor Al-Amlaak',
        'phone': '+96599716851',
        'email': 'kotawalafamily@gmail.com',
        'photo': '${base}kotawala.jpg',
        'color': '#607d8b',
      },
      {
        'name': 'Mulla Nooruddin bhai Qutbuddin bhai Shakir',
        'post': 'Member',
        'umoor': 'Umoor Al-Sehhat',
        'phone': '+96597824379',
        'email': 'sirnuruddin100@gmail.com',
        'photo': '${base}bhabhra.png',
        'color': '#50c777',
      },
      {
        'name': 'Shaikh Burhanuddin bhai Saifuddin bhai Kundawala',
        'post': 'Joint Secretary / FMB Joint Finance',
        'phone': '+96599868127',
        'email': 'bkundawala@hotmail.com',
        'photo': '${base}kunda.jpg',
        'color': '#809248',
      },
      {
        'name': 'Shaikh Abbas bhai Taher bhai Jamali (Mora)',
        'post': 'Qardan Hasana Secretary',
        'phone': '+96597434423',
        'email': 'akmpedo@gmail.com',
        'photo': '${base}mora.jpg',
        'color': '#76bee6',
      },
      {
        'name': 'Mulla Ahmed bhai Shaikh Abidhusain bhai Mavliwala',
        'post': 'Qardan Hasana J. Secretar / Chartered Accountant',
        'phone': '+96565851398',
        'email': 'caiqbalbohra@gmail.com',
        'photo': '${base}Mavli.jpg',
        'color': '#f7ae61',
      },
      {
        'name': 'Shaikh Akber Bhai Rayli wala',
        'post': 'Qardan Hasana Treasurer',
        'color': '#f7ae61',
      },
      {
        'name': 'Shaikh Husain bhai Shaikh Najafali bhai Gari',
        'post': 'Qardan Hasana Treasurer / Chartered Accountant',
        'phone': '+96597584345',
        'email': 'hussaingari@hotmail.com',
        'photo': '${base}Gari.png',
        'color': '#d4b13d',
      },
      {
        'name': 'Mulla Shabbir bhai Shaikh Turabali bhai Kanorewala',
        'post': 'Accounts Software Developer',
        'phone': '+96566884245',
        'email': 'skanore@gmail.com',
        'photo': '${base}Kanorewala.jpg',
        'color': '#ddcb4d',
      },
      {
        'name': 'Shaikh Khuzema bhai Badri',
        'post': 'International Tehsurin Nikah Committee',
        'phone': '+96599675810',
        'color': '#c9a6ce',
      },
      {
        'name': 'Mulla Mustafa bhai Dungarpurwala',
        'post': 'Secretary - Shabab Eid uz Zahabi',
        'phone': '+96597501852',
        'color': '#ddcb4d',
      },
      {
        'name': 'Mulla hakimuddin bhai Khedapa',
        'post': 'Secretary - BGI',
        'phone': '+96598808878',
        'color': '#d4b13d',
      },
    ];

    return [
      for (var i = 0; i < rows.length; i++)
        CommitteeMember.fromJson({
          'id': '${i + 1}',
          ...rows[i],
        }),
    ];
  }
}
