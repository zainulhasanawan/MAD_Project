import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isLoadingSuggestions = false;
  String? _aiSuggestions;
  int totalEntries = 0;
  int totalCountries = 0;
  int totalCities = 0;
  List<String> countriesVisited = [];
  List<String> citiesVisited = [];
  String? firstTripDate;
  String? lastTripDate;
  Map<String, int> monthlyTrips = {};
  Map<String, int> countryDistribution = {};
  List<Map<String, dynamic>> recentEntries = [];

  static const String _groqUrl = "https://api.groq.com/openai/v1/chat/completions";
  static final String _groqApiKey = dotenv.env['GROQ_API_KEY'] ?? '';
  static const String _model = "llama-3.1-8b-instant";

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch statistics from travel_statistics table
      final statsResponse = await supabase
          .from('travel_statistics')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (statsResponse != null) {
        totalEntries = statsResponse['total_entries'] ?? 0;
        totalCountries = statsResponse['total_countries'] ?? 0;
        totalCities = statsResponse['total_cities'] ?? 0;
        firstTripDate = statsResponse['first_trip_date'];
        lastTripDate = statsResponse['last_trip_date'];

        final countriesJson = statsResponse['countries_visited'];
        if (countriesJson is List) {
          countriesVisited = List<String>.from(countriesJson);
        }

        final citiesJson = statsResponse['cities_visited'];
        if (citiesJson is List) {
          citiesVisited = List<String>.from(citiesJson);
        }
      }

      // Fetch actual entries for detailed analysis
      final entries = await supabase
          .from('travel_entries')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      if (entries.isNotEmpty) {
        _calculateMonthlyTrips(entries);
        _calculateCountryDistribution(entries);
        recentEntries = entries.take(5).toList().cast<Map<String, dynamic>>();
      }

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading statistics: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateMonthlyTrips(List<dynamic> entries) {
    final currentYear = DateTime.now().year;
    final monthCounts = <String, int>{};

    for (var entry in entries) {
      final visitDate = entry['visit_start_date'] as String?;
      if (visitDate != null) {
        try {
          final parts = visitDate.split(' ');
          if (parts.length >= 3) {
            final monthStr = parts[0];
            final year = int.tryParse(parts[2].replaceAll(',', ''));
            if (year == currentYear) {
              monthCounts[monthStr] = (monthCounts[monthStr] ?? 0) + 1;
            }
          }
        } catch (_) {}
      }
    }
    monthlyTrips = monthCounts;
  }

  void _calculateCountryDistribution(List<dynamic> entries) {
    final countryCount = <String, int>{};

    for (var entry in entries) {
      final country = entry['country_name'];
      if (country != null) {
        countryCount[country] = (countryCount[country] ?? 0) + 1;
      }
    }

    final sorted = countryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    countryDistribution = Map.fromEntries(sorted.take(5));
  }

  // ------------------- AI SUGGESTIONS -------------------
  Future<void> _generateAISuggestions() async {
    if (countriesVisited.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Add some travel memories first!', style: GoogleFonts.poppins()),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingSuggestions = true);

    try {
      final visitedCountries = countriesVisited.join(', ');
      final visitedCities = citiesVisited.take(12).join(', ');

      final prompt = '''
Based on my travel history, suggest 3 new travel destinations I might enjoy.

My travel profile:
- Countries visited: $visitedCountries
- Cities explored: $visitedCities
- Total trips: $totalEntries

Give me:
1. Three destination recommendations with brief explanations (2-3 sentences each)
2. Why each fits my travel style
3. Best time to visit

Format each as:
[Destination Name]
[2-3 sentences]
Best time: [months/season]
''';

      final response = await http.post(
        Uri.parse(_groqUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_groqApiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
              'You are a friendly travel advisor. Be enthusiastic, concise, and helpful.'
            },
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.8,
          'max_tokens': 800,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['choices']?[0]?['message']?['content'] ?? 'No suggestions received.';
        setState(() {
          _aiSuggestions = text.trim();
          _isLoadingSuggestions = false;
        });
      } else {
        throw Exception('API error ${response.statusCode}');
      }
    } catch (e) {
      print('AI suggestion error: $e');
      setState(() => _isLoadingSuggestions = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to generate suggestions. Try again.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F8FC),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF3D8BFF)),
        ),
      );
    }

    if (totalEntries == 0) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F8FC),
        appBar: _buildAppBar(),
        body: _buildEmptyState(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FC),
      appBar: _buildAppBar(),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double availH = constraints.maxHeight;
            final double availW = constraints.maxWidth;
            final double barChartH = (availH * 0.20).clamp(110.0, 200.0);
            final double pieChartH = (availH * 0.25).clamp(140.0, 220.0);

            return RefreshIndicator(
              onRefresh: _loadStatistics,
              color: const Color(0xFF3D8BFF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 16, 16, kBottomNavigationBarHeight + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 18),
                    if (firstTripDate != null && lastTripDate != null) _buildJourneyTimeline(),
                    const SizedBox(height: 18),
                    if (monthlyTrips.isNotEmpty) _buildMonthlyActivity(barChartH),
                    const SizedBox(height: 18),
                    if (countryDistribution.isNotEmpty) _buildCountryDistribution(pieChartH, availW),
                    const SizedBox(height: 18),

                    // AI CARD INSERTED HERE
                    _buildAISuggestionsCard(),

                    const SizedBox(height: 18),
                    if (recentEntries.isNotEmpty) _buildRecentMemories(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAISuggestionsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6B46C1).withOpacity(0.1),
            const Color(0xFF3D8BFF).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3D8BFF).withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF6B46C1), Color(0xFF3D8BFF)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Next Adventure Awaits',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17),
                    ),
                    Text(
                      'AI-powered suggestions based on your travels',
                      style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Initial State
          if (_aiSuggestions == null && !_isLoadingSuggestions)
            Center(
              child: Column(
                children: [
                  Icon(Icons.explore_outlined, size: 70, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Tap below to discover personalized destinations\nbased on the places you\'ve already explored',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 13.5, color: Colors.grey[600], height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _generateAISuggestions,
                    icon: const Icon(Icons.rocket_launch, size: 22),
                    label: Text('Find My Next Trip', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D8BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 3,
                    ),
                  ),
                ],
              ),
            ),

          // Loading
          if (_isLoadingSuggestions)
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(color: Color(0xFF3D8BFF), strokeWidth: 3),
                  const SizedBox(height: 20),
                  Text(
                    'Analyzing your journey across ${countriesVisited.length} countries...',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),

          // Results - Column-Based Layout
          if (_aiSuggestions != null && !_isLoadingSuggestions)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reference to user's travel history
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3D8BFF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF3D8BFF).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: const Color(0xFF2A6BFF), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Based on your visits to ${countriesVisited.take(5).join(', ')}${countriesVisited.length > 5 ? ' and more' : ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2A6BFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Suggestions in vertical column layout
                ..._buildStyledSuggestions(_aiSuggestions!),

                const SizedBox(height: 20),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _aiSuggestions = null),
                      icon: const Icon(Icons.clear, size: 19),
                      label: Text('Clear', style: GoogleFonts.poppins(fontSize: 13.5)),
                      style: TextButton.styleFrom(foregroundColor: Colors.grey[600]),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: _generateAISuggestions,
                      icon: const Icon(Icons.refresh, size: 19),
                      label: Text('New Ideas', style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF3D8BFF)),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

// Helper method to build styled suggestions in column format
  List<Widget> _buildStyledSuggestions(String suggestions) {
    final lines = suggestions.split('\n').where((line) => line.trim().isNotEmpty).toList();
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();

      // Check if it's a numbered destination (e.g., "1. Country Name" or "1. **Country Name**")
      final destinationMatch = RegExp(r'^(\d+)\.\s*\*?\*?(.+?)\*?\*?$').firstMatch(line);

      if (destinationMatch != null) {
        final number = destinationMatch.group(1);
        final destination = destinationMatch.group(2)?.trim() ?? '';

        // Look ahead for description lines
        final descriptionLines = <String>[];
        int j = i + 1;
        while (j < lines.length && !RegExp(r'^\d+\.').hasMatch(lines[j])) {
          final descLine = lines[j].trim();
          if (descLine.isNotEmpty && !descLine.startsWith('*') && !descLine.startsWith('-')) {
            descriptionLines.add(descLine);
          }
          j++;
        }

        // Create destination card
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[300]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Destination header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6B46C1), Color(0xFF3D8BFF)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          number!,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destination,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
                          if (descriptionLines.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              descriptionLines.join(' '),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        // Skip the description lines we've already processed
        i = j - 1;
      }
    }

    if (widgets.isEmpty) {
      // Fallback if parsing fails - display as simple text
      widgets.add(
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Text(
            suggestions,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[800],
              height: 1.6,
            ),
          ),
        ),
      );
    }

    return widgets;
  }
  // Helper: Converts raw AI text into beautifully styled widgets
  List<Widget> _parseAndStyleSuggestions(String rawText) {
    final lines = rawText.split('\n');
    final List<Widget> widgets = [];
    String? currentTitle;
    bool isFirstLine = true;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Detect destination title (usually starts with number or bold text)
      if (line.startsWith(RegExp(r'^\d+\.|[A-Z][a-zA-Z\s,&]+:')) ||
          line.contains(' in ') ||
          line.length > 5 && line[0] == line[0].toUpperCase() && !line.contains('.')) {

        if (currentTitle != null) {
          widgets.add(const SizedBox(height: 20));
        }

        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF3D8BFF), Color(0xFF6B46C1)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Text(' Popular Destination ', style: TextStyle(fontSize: 18)),
                Expanded(
                  child: Text(
                    line.replaceAll(RegExp(r'^\d+\.\s*|[:]$'), '').trim(),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        currentTitle = line;
        isFirstLine = false;
      }
      // Best time to visit
      else if (line.toLowerCase().contains('best time') || line.contains('📅')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Row(
              children: [
                const Icon(Icons.wb_sunny, color: Color(0xFFFFB800), size: 20),
                const SizedBox(width: 8),
                Text(
                  line.replaceAll('Best time:', '').replaceAll('📅', '').trim(),
                  style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF2E7D32)),
                ),
              ],
            ),
          ),
        );
      }
      // Regular description lines
      else if (line.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Text(
              line.replaceAll('*', '').trim(),
              style: GoogleFonts.poppins(fontSize: 14, height: 1.55, color: Colors.black87),
            ),
          ),
        );
      }
    }

    return widgets;
  }
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text('Statistics', style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18)),
      actions: [
        IconButton(icon: const Icon(Icons.refresh, color: Color(0xFF3D8BFF)), onPressed: _loadStatistics),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No travel data yet', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[400])),
          const SizedBox(height: 8),
          Text('Start adding memories to see your stats', style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(width: double.infinity, child: _statCard('Total Memories', totalEntries.toString(), Icons.collections_bookmark, Colors.blue)),
        SizedBox(width: double.infinity, child: _statCard('Countries Visited', totalCountries.toString(), Icons.public, Colors.green)),
        SizedBox(width: double.infinity, child: _statCard('Cities Explored', totalCities.toString(), Icons.location_city, Colors.orange)),
      ],
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: iconColor.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 24)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJourneyTimeline() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: Color(0xFF3D8BFF), size: 20),
              const SizedBox(width: 8),
              Text('Your Journey', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _journeyMini('First Trip', firstTripDate!),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              _journeyMini('Latest Trip', lastTripDate!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _journeyMini(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMonthlyActivity(double chartHeight) {
    const monthOrder = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    final bars = List.generate(12, (i) {
      final monthName = monthOrder[i];
      final count = monthlyTrips[monthName] ?? 0;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: const Color(0xFF4F9AFF),
            width: 16,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          )
        ],
      );
    });

    final maxValue = monthlyTrips.values.isEmpty ? 5.0 : monthlyTrips.values.reduce((a, b) => a > b ? a : b).toDouble() + 2;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Monthly Activity ${DateTime.now().year}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          SizedBox(
            height: chartHeight,
            child: BarChart(
              BarChartData(
                barGroups: bars,
                alignment: BarChartAlignment.spaceAround,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        return Text(
                          (idx >= 0 && idx < monthOrder.length) ? monthOrder[idx] : '',
                          style: GoogleFonts.poppins(fontSize: 9),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                maxY: maxValue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryDistribution(double chartHeight, double availWidth) {
    final sections = <PieChartSectionData>[];
    final colors = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.pink];
    final entries = countryDistribution.entries.toList();
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final percentage = ((e.value / total) * 100).round();
      sections.add(
        PieChartSectionData(
          value: e.value.toDouble(),
          title: '$percentage%',
          color: colors[i % colors.length],
          radius: 55,
          titleStyle: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Countries', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 20),
          SizedBox(
            height: chartHeight,
            child: Row(
              children: [
                Flexible(flex: 3, child: Padding(padding: const EdgeInsets.only(right: 12), child: PieChart(PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 35)))),
                Flexible(flex: 2, child: _buildCountriesLegend(maxWidth: availWidth * 0.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountriesLegend({double? maxWidth}) {
    final colors = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.pink];
    final entries = countryDistribution.entries.toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(entries.length, (i) {
          final key = entries[i].key;
          final value = entries[i].value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(width: 14, height: 14, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text('$key ($value)', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500))),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRecentMemories() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Memories', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          ...recentEntries.map((entry) => _recentMemoryTile(entry)),
        ],
      ),
    );
  }

  Widget _recentMemoryTile(Map<String, dynamic> entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF3D8BFF), shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry['title'] ?? 'Untitled', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(entry['visit_start_date'] ?? '', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}