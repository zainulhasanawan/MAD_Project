import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({Key? key}) : super(key: key);

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final supabase = Supabase.instance.client;

  bool _isLoading = true;

  // Statistics from database
  int totalEntries = 0;
  int totalCountries = 0;
  int totalCities = 0;
  List<String> countriesVisited = [];
  List<String> citiesVisited = [];
  String? firstTripDate;
  String? lastTripDate;

  // Calculated data
  Map<String, int> monthlyTrips = {};
  Map<String, int> countryDistribution = {};
  List<Map<String, dynamic>> recentEntries = [];

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

        // Parse countries and cities from JSONB
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
        // Calculate monthly trips for current year
        _calculateMonthlyTrips(entries);

        // Calculate country distribution
        _calculateCountryDistribution(entries);

        // Get recent entries
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
        } catch (e) {
          // Skip if date parsing fails
        }
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

    // Sort and get top 5
    final sortedCountries = countryCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    countryDistribution = Map.fromEntries(sortedCountries.take(5));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F8FC),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3D8BFF),
          ),
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

            // Increased pie chart height for more vertical space
            final double pieChartH = (availH * 0.25).clamp(140.0, 220.0);

            return RefreshIndicator(
              onRefresh: _loadStatistics,
              color: const Color(0xFF3D8BFF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, kBottomNavigationBarHeight + 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    _buildSummaryCards(),

                    const SizedBox(height: 18),

                    // Journey Timeline
                    if (firstTripDate != null && lastTripDate != null)
                      _buildJourneyTimeline(),

                    const SizedBox(height: 18),

                    // Monthly Activity
                    if (monthlyTrips.isNotEmpty)
                      _buildMonthlyActivity(barChartH),

                    const SizedBox(height: 18),

                    // Country Distribution
                    if (countryDistribution.isNotEmpty)
                      _buildCountryDistribution(pieChartH, availW),

                    const SizedBox(height: 18),

                    // Recent Memories
                    if (recentEntries.isNotEmpty)
                      _buildRecentMemories(),

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

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'Statistics',
        style: GoogleFonts.poppins(
          color: Colors.black87,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF3D8BFF)),
          onPressed: _loadStatistics,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No travel data yet',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding memories to see your stats',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        SizedBox(
          width: double.infinity,
          child: _statCard(
            'Total Memories',
            totalEntries.toString(),
            Icons.collections_bookmark,
            Colors.blue,
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: _statCard(
            'Countries Visited',
            totalCountries.toString(),
            Icons.public,
            Colors.green,
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: _statCard(
            'Cities Explored',
            totalCities.toString(),
            Icons.location_city,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildJourneyTimeline() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timeline,
                color: Color(0xFF3D8BFF),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Journey',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _journeyMini('First Trip', firstTripDate!),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              _journeyMini('Latest Trip', lastTripDate!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyActivity(double chartHeight) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monthly Activity ${DateTime.now().year}',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: chartHeight,
            child: _buildBarChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryDistribution(double chartHeight, double availWidth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18), // Increased padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Countries',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20), // Increased spacing
          SizedBox(
            height: chartHeight,
            child: Row(
              children: [
                Flexible(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildPieChart(),
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: _buildCountriesLegend(maxWidth: availWidth * 0.45),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRecentMemories() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Memories',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ...recentEntries.map((entry) => _recentMemoryTile(entry)),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
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
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    const monthOrder = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];

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

    final maxValue = monthlyTrips.values.isEmpty
        ? 5.0
        : monthlyTrips.values.reduce((a, b) => a > b ? a : b).toDouble();

    return BarChart(
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
                final text = (idx >= 0 && idx < monthOrder.length) ? monthOrder[idx] : '';
                return Text(text, style: GoogleFonts.poppins(fontSize: 9));
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        maxY: (maxValue + 2),
      ),
    );
  }

  Widget _buildPieChart() {
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
          radius: 55, // Slightly larger radius
          titleStyle: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sections: sections,
        sectionsSpace: 2,
        centerSpaceRadius: 35, // Slightly larger center space
      ),
    );
  }

  Widget _buildCountriesLegend({double? maxWidth}) {
    final colors = [Colors.blue, Colors.orange, Colors.green, Colors.purple, Colors.pink];
    final entries = countryDistribution.entries.toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(entries.length, (i) {
        final key = entries[i].key;
        final value = entries[i].value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8), // Increased vertical padding
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 14, // Slightly larger dot
                height: 14,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10), // Increased spacing
              Expanded(
                child: Text(
                  '$key ($value)',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13, // Slightly larger font
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _recentMemoryTile(Map<String, dynamic> entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF3D8BFF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry['title'] ?? 'Untitled',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry['visit_start_date'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
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