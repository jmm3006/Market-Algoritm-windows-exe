import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Widget historyPage({
  required List<Map<String, dynamic>> histories,
  required bool isLoading,
  required Future<void> Function() onRefreshHistories,
}) {
  return Column(
    children: [
      const SizedBox(height: 10),
      const Text(
        'Sotuv Tarixi',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: onRefreshHistories,
          child: histories.isEmpty && isLoading
              ? const Center(child: CircularProgressIndicator())
              : histories.isEmpty && !isLoading
              ? const Center(child: Text('Tarix ma\'lumotlari topilmadi.'))
              : ListView.builder(
            itemCount: histories.length,
            itemBuilder: (context, index) {
              var h = histories[index];
              String datePart = 'N/A';
              String timePart = 'N/A';
              if (h['sana_vaqt'] != null) {
                try {
                  DateTime originalDateTime = DateTime.parse(h['sana_vaqt'].toString());
                  DateTime adjustedDateTime = originalDateTime.add(const Duration(hours: 5));
                  datePart = DateFormat('dd.MM.yyyy').format(adjustedDateTime);
                  timePart = DateFormat('HH:mm').format(adjustedDateTime);
                } catch (e) {
                  datePart = h['sana_vaqt'].toString();
                  timePart = '';
                }
              }

              String comment = h['comment'] ?? '';
              if (comment.isEmpty) {
                comment = 'Izoh: Kiritilmagan';
              } else {
                comment = 'Izoh: $comment';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  title: Text(
                    h['name'] ?? 'Noma\'lum mahsulot',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sana: $datePart, Vaqt: $timePart',
                        style: const TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                      Text(
                        'Narx: ${h['price'] ?? 0} so‘m, Miqdor: ${h['quantity'] ?? 0}, Summa: ${h['summa'] ?? 0} so‘m',
                        style: const TextStyle(color: Colors.black87, fontSize: 14),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          comment,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  );
}