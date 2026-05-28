import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crmx/database_service.dart';
import 'package:crmx/service_model.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart'; 
// Define your color palette here for easy adjustments
class ItineraryColors {
  static const PdfColor primary = PdfColor.fromInt(0xFF0D47A1); // Deep Blue
  static const PdfColor accent = PdfColor.fromInt(0xFFFF6F00);  // Deep Orange
  static const PdfColor background = PdfColor.fromInt(0xFFFFFFFF); // White
  static const PdfColor textMain = PdfColor.fromInt(0xFF212121);
  static const PdfColor textLight = PdfColor.fromInt(0xFF757575);
  static const PdfColor lightGrey = PdfColor.fromInt(0xFFEEEEEE);
}


class ItineraryServices {
 
  // --- AI Generation (Updated with Restricted Destinations) ---


Future<Map<String, dynamic>> generateItineraryWithAI({
  required String destination, // General destination (e.g., "Vietnam")
  required DateTime startDate,
  required DateTime endDate,
  required List<String> serviceNames,
  required String clientNotes,
  required List<String> allowedDestinations,
  required List<String> dailyTowns, // <--- New Parameter from UI
}) async {
  
  List<String> allowedSpots = [];
  for (var city in allowedDestinations){
    List<String> spots = await DatabaseService().getSpotsForDestination(city);
    String entry  = "$city: $spots";
    allowedSpots.add(entry);
  }
  // 1. Calculate duration
  int days = endDate.difference(startDate).inDays + 1;

  // 2. Validate inputs
  if (dailyTowns.length < days) {
    // Fallback: Fill remaining days with the last selected city if list is short
    final lastCity = dailyTowns.isNotEmpty ? dailyTowns.last : destination;
    while (dailyTowns.length < days) {
      dailyTowns.add(lastCity);
    }
  }

  // 3. Create a readable schedule string for the AI
  StringBuffer scheduleBuffer = StringBuffer();
  for (int i = 0; i < days; i++) {
    scheduleBuffer.writeln("Day ${i + 1}: ${dailyTowns[i]}");
  }

  // 4. Initialize AI Model

  final model = FirebaseAI.googleAI().generativeModel(model: 'gemini-2.5-flash');

  // 5. Build the Prompt
  final promptText = '''
  Act as an expert travel agent. Create a $days-day itinerary for a trip to $destination.
  
  STRICT SCHEDULE INSTRUCTIONS:
  You must strictly follow this city schedule. The activities for each day MUST take place in the specified city.
  $scheduleBuffer

  ADDITIONAL INSTRUCTIONS:
  1. Allowed Cities,Spot List: $allowedSpots.
  2. Incorporate these booked services if applicable: ${serviceNames.join(', ')}.
  3. Client Notes: $clientNotes
  4. The "location" field must be the City Name (from the schedule).
  5. The "spot" field must be the specific tourist attraction name.

  OUTPUT FORMAT (Raw JSON only):
  {
    "trip_title": "Creative Trip Title",
    "days": [
      {
        "day_number": 1,
        "theme": "Short theme description (e.g. History & Culture)",
        "activities": [
          { 
            "time": "09:00 AM", 
            "location": "City Name (Must match schedule)", 
            "spot": "Specific Attraction Name", 
            "description": "Engaging description of activity" 
          }
        ]
      }
    ]
  }
  ''';

  // 6. Generate Content
  try {
    final content = [Content.text(promptText)];
    final response = await model.generateContent(content);

    String? rawText = response.text;
    if (rawText == null) throw Exception("AI returned empty response");

    // Clean markdown if the AI adds it (though responseMimeType usually prevents this)
    rawText = rawText.replaceAll('```json', '').replaceAll('```', '').trim();

    return jsonDecode(rawText) as Map<String, dynamic>;
  } catch (e) {
    print("AI Generation Error: $e");
    // Return a fallback structure so the app doesn't crash
    return {
      "trip_title": "Error Generating Itinerary",
      "days": []
    };
  }
}

 


Future<void> generateAndDownloadItineraryPdf(
    Map<String, dynamic> data, String clientName) async {
  final pdf = pw.Document();

  final String title = data['trip_title'] ?? 'Luxury Vacation';
  final List<dynamic> days = data['days'] ?? [];

  // Dummy Company Info
  const String companyName = "journeytale";
  const String companyAddress = "123 Sunshine Blvd, Suite 404\nSingapore, 000000";
  const String companyEmail = "bookings@wanderlusttravels.dummy";
  const String contactPerson = "Victor Ong (Senior Agent)";

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.openSansRegular(),
        bold: await PdfGoogleFonts.openSansBold(),
      ),
      build: (pw.Context context) {
        return [
          // 1. HEADER SECTION
          _buildHeader(companyName, companyAddress, companyEmail, contactPerson),
          pw.SizedBox(height: 20),

          // 2. TRIP TITLE SECTION
          _buildTitleSection(title, clientName),
          pw.SizedBox(height: 30),

          // 3. ITINERARY BODY (Timeline View)
          ...days.map((day) => _buildDaySection(day)).toList(),
          
          // 4. FOOTER / SIGN OFF
          pw.SizedBox(height: 40),
          pw.Divider(color: ItineraryColors.lightGrey),
          pw.Center(
            child: pw.Text(
              "Thank you for choosing $companyName. We wish you a safe journey!",
              style: const pw.TextStyle(color: ItineraryColors.textLight, fontSize: 10),
            ),
          ),
        ];
      },
    ),
  );

  await Printing.sharePdf(
      bytes: await pdf.save(), filename: 'Itinerary_$clientName.pdf');
}

// --- HELPER WIDGETS ---

pw.Widget _buildHeader(
    String company, String address, String email, String contact) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Left: Logo & Company Name
      pw.Row(
        children: [
          // Drawing a vector logo placeholder (Compass shape)
          pw.Container(
            height: 50,
            width: 50,
            decoration: const pw.BoxDecoration(
              color: ItineraryColors.primary,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.Text("W", 
                style: pw.TextStyle(color: PdfColors.white, fontSize: 30, fontWeight: pw.FontWeight.bold))
            ),
          ),
          pw.SizedBox(width: 15),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(company,
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: ItineraryColors.primary)),
              pw.Text("Explore the world with us.",
                  style: const pw.TextStyle(
                      fontSize: 10, color: ItineraryColors.accent)),
            ],
          ),
        ],
      ),
      // Right: Contact Details
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(address,
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 10, color: ItineraryColors.textLight)),
          pw.SizedBox(height: 4),
          pw.Text("Email: $email",
              style: const pw.TextStyle(fontSize: 10, color: ItineraryColors.textMain)),
          pw.Text("Contact: $contact",
              style: const pw.TextStyle(fontSize: 10, color: ItineraryColors.textMain)),
        ],
      ),
    ],
  );
}

pw.Widget _buildTitleSection(String title, String clientName) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(15),
    decoration: pw.BoxDecoration(
      color: ItineraryColors.primary, // Very light blue bg
      borderRadius: pw.BorderRadius.circular(10),
      border: pw.Border.all(color: ItineraryColors.primary,
    ),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("TRAVEL ITINERARY",
                style: pw.TextStyle(
                    fontSize: 10,
                    letterSpacing: 2,
                    color: ItineraryColors.accent,
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Text(title,
                style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: ItineraryColors.primary)),
          ],
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: ItineraryColors.accent,
            borderRadius: pw.BorderRadius.circular(20),
          ),
          child: pw.Text("Client: $clientName",
              style: pw.TextStyle(
                  color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
        ),
      ],
    ),
  );
}

pw.Widget _buildDaySection(dynamic day) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 25),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Day Header Pill
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: const pw.BoxDecoration(
            color: ItineraryColors.primary,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(10),
              bottomRight: pw.Radius.circular(10),
            ),
          ),
          child: pw.Text(
            "Day ${day['day_number']} | ${day['theme']}",
            style: pw.TextStyle(
                color: PdfColors.white, fontWeight: pw.FontWeight.bold),
          ),
        ),
        
        // Activities List
        pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(left: pw.BorderSide(color: ItineraryColors.lightGrey, width: 2)),
          ),
          margin: const pw.EdgeInsets.only(left: 10),
          padding: const pw.EdgeInsets.only(left: 20),
          child: pw.Column(
            children: (day['activities'] as List).map((act) {
              return _buildActivityRow(act);
            }).toList(),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildActivityRow(dynamic act) {
  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 15),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Time Column
        pw.SizedBox(
          width: 60,
          child: pw.Text(
            act['time'],
            style: pw.TextStyle(
              color: ItineraryColors.accent,
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        // Details Column
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: ItineraryColors.background,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: ItineraryColors.lightGrey),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(children: [
                  pw.Icon(pw.IconData(0xe0c8), color: ItineraryColors.primary, size: 12), // Location Icon
                  pw.SizedBox(width: 5),
                  pw.Text(
                    "${act['location']}, ${act['spot']}",
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                        color: ItineraryColors.primary),
                  ),
                ]),
                pw.SizedBox(height: 5),
                pw.Text(
                  act['description'],
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: ItineraryColors.textMain,
                    lineSpacing: 2
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
  // --- PDF: Invoice Generator (NEW) ---
  // Generate and Download Invoice PDF
  Future<void> generateAndDownloadInvoice({
    required OrderModel order,
    required List<Map<String, dynamic>> services,
    required List<Map<String, dynamic>> fees,
  }) async {
    final pdf = pw.Document();
    final date = DateTime.now();
    final format = NumberFormat.simpleCurrency(decimalDigits: 2);
    final dateFormat = DateFormat('dd MMM yyyy');

    // --- 1. Calculate Financials ---
    double subtotal = 0;
    List<Map<String, dynamic>> lineItems = [];

    // Process Services
    for (var data in services) {
      final double price = (data['price_per_day'] as num?)?.toDouble() ?? 0.0;
      final int days = (data['days'] as num?)?.toInt() ?? 1;
      final double discount = (data['discount'] as num?)?.toDouble() ?? 0.0;
      
      // Calculate Dates for display
      String dateRange = "$days Days";
      if (data['start_date'] != null) {
        // Handle Firestore Timestamp conversion safely
        final start = (data['start_date'] as Timestamp).toDate();
        final end = data['end_date'] != null 
            ? (data['end_date'] as Timestamp).toDate() 
            : start.add(Duration(days: days - 1));
        dateRange = "${DateFormat('dd MMM yyyy').format(start)} - ${DateFormat('dd MMM yyyy').format(end)} ($days days)";
      }

      double lineTotal = (price * days) - discount;
      subtotal += lineTotal;

      lineItems.add({
        "name": data['name'] ?? "Service",
        "desc": dateRange,
        "rate": price,
        "discount": discount,
        "total": lineTotal
      });
    }

    // Process Additional Fees
    for (var fee in fees) {
      final amount = (fee['amount'] as num?)?.toDouble() ?? 0.0;
      subtotal += amount;
      lineItems.add({
        "name": fee['description'] ?? "Fee",
        "desc": "Additional Charge",
        "rate": amount,
        "discount": 0.0,
        "total": amount
      });
    }

    // --- 2. Build PDF Layout ---
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(
        base: await PdfGoogleFonts.openSansRegular(),
        bold: await PdfGoogleFonts.openSansBold(),
      ),
      build: (pw.Context context) {
        const primaryColor = PdfColor.fromInt(0xFF0D47A1); // Deep Blue
        const accentColor = PdfColor.fromInt(0xFFFF6F00);  // Orange

        return [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("INVOICE", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.SizedBox(height: 4),
                pw.Text("Date: ${dateFormat.format(date)}", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text("journeytale Travels", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.Text("contact@journeytale.com", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              ])
            ]
          ),
          pw.SizedBox(height: 20),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 20),

          // Bill To
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("BILL TO", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accentColor)),
                pw.SizedBox(height: 4),
                pw.Text(order.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text("Destination: ${order.destination}"),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text("TRIP DATES", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accentColor)),
                pw.SizedBox(height: 4),
                pw.Text("${dateFormat.format(order.startDate)} - ${dateFormat.format(order.endDate)}"),
                pw.Text("${order.durationDays} Days"),
              ]),
            ]
          ),
          pw.SizedBox(height: 30),

          // Table Header
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: const pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(4))),
            child: pw.Row(children: [
              pw.Expanded(flex: 3, child: pw.Text("SERVICE", style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Expanded(flex: 2, child: pw.Text("DETAILS", style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Expanded(flex: 1, child: pw.Text("RATE", textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))),
              pw.Expanded(flex: 1, child: pw.Text("TOTAL", textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10))),
            ])
          ),

          // Table Items
          ...lineItems.map((item) {
            final isFee = item['desc'] == 'Additional Charge';
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200))),
              child: pw.Row(children: [
                pw.Expanded(flex: 3, child: pw.Text(item['name'], style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                pw.Expanded(flex: 2, child: pw.Text(item['desc'], style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
                pw.Expanded(flex: 1, child: pw.Text(isFee ? "-" : format.format(item['rate']), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                pw.Expanded(flex: 1, child: pw.Text(format.format(item['total']), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
              ])
            );
          }),

          pw.SizedBox(height: 20),

          // Grand Total
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 200,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: accentColor,
                  borderRadius: pw.BorderRadius.circular(4)
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text("TOTAL DUE", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.Text(format.format(subtotal), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16, color: primaryColor)),
                  ]
                )
              )
            ]
          ),
          
          pw.Spacer(),
          pw.Center(
             child: pw.Text("Thank you for choosing journeytale Travels!", style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10)),
          )
        ];
      }
    ));
    await Printing.sharePdf(
      bytes: await pdf.save(), filename: 'Invoice_${order.name.replaceAll(" ", "_")}.pdf');
    
  }

  
  
}