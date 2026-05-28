import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

// ==========================================
// 1. DATA MODEL
// ==========================================
class FlightInfo {
  final String flightCode;
  final String airline;
  final String departureAirport;
  final String departureCity;
  final DateTime departureTime;
  final String arrivalAirport;
  final String arrivalCity;
  final DateTime arrivalTime;
  final String status;

  FlightInfo({
    required this.flightCode,
    required this.airline,
    required this.departureAirport,
    required this.departureCity,
    required this.departureTime,
    required this.arrivalAirport,
    required this.arrivalCity,
    required this.arrivalTime,
    required this.status,
  });
}

// ==========================================
// 2. API SERVICE (BACKEND LOGIC)
// ==========================================
class FlightService {
  // Pass at build time: --dart-define=AVIATIONSTACK_API_KEY=your_key
  // Get a free key at aviationstack.com
  static const String _apiKey = String.fromEnvironment('AVIATIONSTACK_API_KEY');
  
  // Note: The free tier of AviationStack only supports HTTP, not HTTPS.
  static const String _baseUrl = 'http://api.aviationstack.com/v1/flights';

  Future<FlightInfo> fetchFlightData(String rawFlightCode) async {
    // 1. Input Sanitization
    final flightCode = rawFlightCode.replaceAll(' ', '').trim().toUpperCase();

    if (flightCode.isEmpty) {
      throw Exception("Please enter a flight code.");
    }
    
    if (_apiKey == 'YOUR_API_KEY_HERE') {
      throw Exception("API Key not set. Please update the code.");
    }

    // 2. Build URL
    final uri = Uri.parse('$_baseUrl?access_key=$_apiKey&flight_iata=$flightCode');

    try {
      // 3. Network Request
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);

        // 4. Validation
        if (jsonResponse['data'] == null || (jsonResponse['data'] as List).isEmpty) {
          throw Exception("Flight $flightCode not found (or not active today).");
        }

        // 5. Extraction (Get the first result)
        final flightData = jsonResponse['data'][0];

        // 6. Mapping JSON to Object (Safe parsing with ??)
        return FlightInfo(
          flightCode: flightData['flight']['iata'] ?? flightCode,
          airline: flightData['airline']['name'] ?? 'Unknown Airline',
          
          departureAirport: flightData['departure']['iata'] ?? 'N/A',
          departureCity: flightData['departure']['airport'] ?? 'Dep Airport',
          // Prefer actual time, fall back to scheduled
          departureTime: _parseTime(
            flightData['departure']['actual'] ?? flightData['departure']['scheduled']
          ),
          
          arrivalAirport: flightData['arrival']['iata'] ?? 'N/A',
          arrivalCity: flightData['arrival']['airport'] ?? 'Arr Airport',
          // Prefer estimated time, fall back to scheduled
          arrivalTime: _parseTime(
            flightData['arrival']['estimated'] ?? flightData['arrival']['scheduled']
          ),
          
          status: _capitalize(flightData['flight_status'] ?? 'Unknown'),
        );
      } else {
        throw Exception("API Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // Helper: Safe Date Parsing
  DateTime _parseTime(String? dateString) {
    if (dateString == null) return DateTime.now();
    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return DateTime.now();
    }
  }

  // Helper: Capitalize Status
  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}

// ==========================================
// 3. UI WIDGET
// ==========================================
class FlightLookupWidget extends StatefulWidget {
  const FlightLookupWidget({super.key});

  @override
  State<FlightLookupWidget> createState() => _FlightLookupWidgetState();
}

class _FlightLookupWidgetState extends State<FlightLookupWidget> {
  final TextEditingController _controller = TextEditingController();
  final FlightService _service = FlightService();
  
  FlightInfo? _flightInfo;
  bool _isLoading = false;
  String? _errorMessage;

  void _searchFlight() async {
    FocusScope.of(context).unfocus(); // Hide keyboard

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _flightInfo = null;
    });

    try {
      final result = await _service.fetchFlightData(_controller.text);
      setState(() {
        _flightInfo = result;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- SEARCH BAR ---
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: "Flight Number",
                    hintText: "e.g. AA100",
                    prefixIcon: const Icon(Icons.flight),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _isLoading ? null : _searchFlight,
               
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.search),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // --- ERROR MESSAGE ---
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_errorMessage!, style: TextStyle(color: Colors.red[800]))),
                ],
              ),
            ),

          // --- TICKET DISPLAY ---
          if (_flightInfo != null) _buildFlightTicket(_flightInfo!),
        ],
      ),
    );
  }

  Widget _buildFlightTicket(FlightInfo info) {
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');
    final isLanded = info.status.toLowerCase() == 'landed';

    return Card(
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Header: Airline & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.airlines, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(info.airline, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLanded ? Colors.green[100] : Colors.blue[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    info.status,
                    style: TextStyle(
                      color: isLanded ? Colors.green[800] : Colors.blue[800], 
                      fontWeight: FontWeight.bold, fontSize: 12
                    ),
                  ),
                )
              ],
            ),
            const Divider(height: 30, thickness: 1),
            
            // Body: Route Details
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Departure Column
                _buildAirportColumn(
                  info.departureAirport, 
                  info.departureCity, 
                  timeFormat.format(info.departureTime),
                  dateFormat.format(info.departureTime),
                  CrossAxisAlignment.start
                ),
                
                // Center Icon
                Column(
                  children: [
                    Icon(Icons.flight_takeoff, color: Colors.grey[400]),
                    const SizedBox(height: 4),
                    Text(
                      "${info.arrivalTime.difference(info.departureTime).inHours}h ${info.arrivalTime.difference(info.departureTime).inMinutes.remainder(60)}m",
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const Icon(Icons.arrow_right_alt, size: 24, color: Colors.grey),
                  ],
                ),
                
                // Arrival Column
                _buildAirportColumn(
                  info.arrivalAirport, 
                  info.arrivalCity, 
                  timeFormat.format(info.arrivalTime),
                  dateFormat.format(info.arrivalTime),
                  CrossAxisAlignment.end
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAirportColumn(String code, String city, String time, String date, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(code, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87)),
        SizedBox(
          width: 80,
          child: Text(
            city.replaceAll(' Airport', ''), 
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            overflow: TextOverflow.ellipsis,
            textAlign: align == CrossAxisAlignment.end ? TextAlign.right : TextAlign.left,
          ),
        ),
        const SizedBox(height: 12),
        Text(time, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        Text(date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}