class History {
  final String data;
  final String name;
  final String price;
  final String much;
  final String sum;

  History({required this.data, required this.name, required this.price, required this.much, required this.sum});

  factory History.fromJson(Map<String, dynamic> json) {
    return History(
      data: json['sana_vaqt'],
      name: json['name'],
      price: json['price'],
      much: json['quantity'],
      sum: json['summa'],
    );
  }
}
