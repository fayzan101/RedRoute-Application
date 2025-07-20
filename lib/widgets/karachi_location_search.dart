import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../services/karachi_places_service.dart';
import '../services/isar_database_service.dart';
import '../services/recent_searches_service.dart';
import '../models/place_isar.dart';
import '../utils/distance_calculator.dart';

// Unified place type that can represent both KarachiPlace and PlaceIsar
class UnifiedPlace {
  final String name;
  final double lat;
  final double lon;
  final String displayName;
  final String subtitle;
  final String type;

  UnifiedPlace({
    required this.name,
    required this.lat,
    required this.lon,
    required this.displayName,
    required this.subtitle,
    this.type = 'place',
  });

  factory UnifiedPlace.fromKarachiPlace(KarachiPlace place) {
    return UnifiedPlace(
      name: place.name,
      lat: place.lat,
      lon: place.lon,
      displayName: place.displayName,
      subtitle: place.subtitle,
      type: 'place',
    );
  }

  factory UnifiedPlace.fromPlaceIsar(PlaceIsar place) {
    return UnifiedPlace(
      name: place.name,
      lat: place.lat,
      lon: place.lon,
      displayName: place.displayName,
      subtitle: place.subtitle,
      type: 'place',
    );
  }

  factory UnifiedPlace.fromRecentSearch(RecentSearch search) {
    return UnifiedPlace(
      name: search.name.isNotEmpty ? search.name : 'Unknown Place',
      lat: search.latitude,
      lon: search.longitude,
      displayName: search.name.isNotEmpty ? search.name : 'Unknown Place',
      subtitle: search.subtitle.isNotEmpty ? search.subtitle : 'Recent search',
      type: 'recent_search',
    );
  }
}

class KarachiLocationSearch extends StatefulWidget {
  final Function(UnifiedPlace)? onPlaceSelected;
  final Function(UnifiedPlace)? onRouteRequested;
  final String? hintText;
  final bool showPopularPlaces;
  final bool showSearchIcon;
  final bool showRecentSearches;
  final EdgeInsetsGeometry? padding;
  final InputDecoration? decoration;
  final TextStyle? textStyle;
  final TextStyle? suggestionTextStyle;

  const KarachiLocationSearch({
    super.key,
    this.onPlaceSelected,
    this.onRouteRequested,
    this.hintText,
    this.showPopularPlaces = true,
    this.showSearchIcon = true,
    this.showRecentSearches = true,
    this.padding,
    this.decoration,
    this.textStyle,
    this.suggestionTextStyle,
  });

  @override
  State<KarachiLocationSearch> createState() => _KarachiLocationSearchState();
}

class _KarachiLocationSearchState extends State<KarachiLocationSearch> {
  final TextEditingController _controller = TextEditingController();
  final RecentSearchesService _recentSearchesService = RecentSearchesService();
  bool _isLoading = false;
  List<RecentSearch> _recentSearches = [];
  bool _showRecentSearches = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    
    // Listen to text changes to show/hide recent searches
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _showRecentSearches = _controller.text.isEmpty && widget.showRecentSearches;
    });
  }



  Future<void> _loadRecentSearches() async {
    if (!widget.showRecentSearches) return;
    
    try {
      final searches = await _recentSearchesService.getRecentSearches();
      
      // Filter out invalid searches
      final validSearches = searches.where((search) => 
        search.name.isNotEmpty && 
        search.subtitle.isNotEmpty &&
        search.query.isNotEmpty
      ).toList();
      
      setState(() {
        _recentSearches = validSearches;
      });
      
      // If we filtered out some searches, update the storage
      if (validSearches.length != searches.length) {
        print('🧹 KarachiLocationSearch: Cleaned ${searches.length - validSearches.length} invalid recent searches');
        await _recentSearchesService.clearRecentSearches();
        for (final search in validSearches) {
          await _recentSearchesService.addRecentSearch(search);
        }
      }
    } catch (e) {
      print('❌ KarachiLocationSearch: Error loading recent searches: $e');
      // Clear corrupted data
      await _recentSearchesService.clearRecentSearches();
      setState(() {
        _recentSearches = [];
      });
    }
  }

  Future<void> _addToRecentSearches(UnifiedPlace place) async {
    if (!widget.showRecentSearches) return;
    
    try {
      // Validate place data before saving
      if (place.displayName.isEmpty || place.subtitle.isEmpty) {
        print('⚠️ KarachiLocationSearch: Skipping invalid place data');
        return;
      }
      
      final recentSearch = RecentSearch(
        query: place.displayName,
        name: place.displayName,
        subtitle: place.subtitle,
        latitude: place.lat,
        longitude: place.lon,
        timestamp: DateTime.now(),
      );
      
      await _recentSearchesService.addRecentSearch(recentSearch);
      await _loadRecentSearches(); // Reload to update the list
    } catch (e) {
      print('❌ KarachiLocationSearch: Error adding to recent searches: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: widget.padding ?? const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Field
          TypeAheadField<UnifiedPlace>(
            controller: _controller,
            debounceDuration: const Duration(milliseconds: 300),
            animationDuration: const Duration(milliseconds: 300),
            builder: (context, controller, focusNode) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                style: widget.textStyle ?? TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 16,
                ),
                decoration: widget.decoration ?? InputDecoration(
                  hintText: widget.hintText ?? 'Search places in Karachi...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 16,
                  ),
                  prefixIcon: widget.showSearchIcon ? Icon(
                    Icons.search,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    size: 24,
                  ) : null,
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          onPressed: () {
                            _controller.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Theme.of(context).primaryColor,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _showRecentSearches = _controller.text.isEmpty && widget.showRecentSearches;
                  });
                },
              );
            },
            suggestionsCallback: (pattern) async {
              print('🔍 KarachiLocationSearch: Search called with pattern: "$pattern"');
              
              if (pattern.length < 1) {
                print('🔍 KarachiLocationSearch: Pattern too short, returning recent searches');
                try {
                  return _recentSearches
                      .where((search) => search.name.isNotEmpty && search.subtitle.isNotEmpty)
                      .map((search) => UnifiedPlace.fromRecentSearch(search))
                      .toList();
                } catch (e) {
                  print('❌ KarachiLocationSearch: Error creating recent search suggestions: $e');
                  return [];
                }
              }
              
              try {
                // Search in Isar database only
                print('🔍 KarachiLocationSearch: Searching Isar database...');
                final isarResults = await IsarDatabaseService.searchPlaces(pattern);
                print('🔍 KarachiLocationSearch: Isar returned ${isarResults.length} results');
                
                final unifiedResults = isarResults.map((place) => UnifiedPlace.fromPlaceIsar(place)).toList();
                print('🔍 KarachiLocationSearch: Converted to ${unifiedResults.length} unified places');
                
                return unifiedResults;
              } catch (e) {
                print('❌ KarachiLocationSearch: Search error: $e');
                return [];
              }
            },
            itemBuilder: (context, UnifiedPlace place) {
              return _buildSuggestionItem(place);
            },
            onSelected: (UnifiedPlace place) {
              _controller.text = place.displayName;
              _addToRecentSearches(place);
              widget.onPlaceSelected?.call(place);
            },
            emptyBuilder: (context) => _buildEmptyState(),
            loadingBuilder: (context) => _buildLoadingState(),
            errorBuilder: (context, error) => _buildErrorState(error),
          ),
          
          // Recent Searches Section (shown when not searching)
          if (_showRecentSearches && _recentSearches.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildRecentSearchesSection(),
          ],
          
          // Debug indicator (can be removed in production)
          if (_isLoading) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text(
                  'Loading from Isar Database...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(UnifiedPlace place) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRecentSearch = place.type == 'recent_search';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isRecentSearch 
              ? Colors.orange.withOpacity(0.1)
              : Theme.of(context).primaryColor.withOpacity(0.1),
          child: Icon(
            isRecentSearch ? Icons.history : Icons.place,
            color: isRecentSearch ? Colors.orange : Theme.of(context).primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          place.displayName,
          style: widget.suggestionTextStyle ?? TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white : Colors.black,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isRecentSearch ? 'Recent search' : place.subtitle,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: widget.onRouteRequested != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      _addToRecentSearches(place);
                      widget.onRouteRequested!(place);
                    },
                    icon: Icon(
                      Icons.directions,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    tooltip: 'Get Route',
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ],
              )
            : Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'No places found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: const Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Searching places...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(dynamic error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Search Error',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSearchesSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Recent Searches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                await _recentSearchesService.clearRecentSearches();
                await _loadRecentSearches();
              },
              icon: Icon(
                Icons.clear_all,
                size: 16,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              label: Text(
                'Clear All',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _recentSearches.length,
          itemBuilder: (context, index) {
            final search = _recentSearches[index];
            final place = UnifiedPlace.fromRecentSearch(search);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  child: Icon(
                    Icons.history,
                    color: Colors.orange,
                    size: 18,
                  ),
                ),
                title: Text(
                  search.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      search.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _formatTimestamp(search.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                trailing: widget.onRouteRequested != null
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              _addToRecentSearches(place);
                              widget.onRouteRequested!(place);
                            },
                            icon: Icon(
                              Icons.directions,
                              color: Theme.of(context).primaryColor,
                              size: 18,
                            ),
                            tooltip: 'Get Route',
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ],
                      )
                    : Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                onTap: () {
                  _controller.text = search.name;
                  _addToRecentSearches(place);
                  widget.onPlaceSelected?.call(place);
                  setState(() {
                    _showRecentSearches = false;
                  });
                },
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }


}

// Extension to add distance calculation to KarachiPlace
extension KarachiPlaceDistance on KarachiPlace {
  double getDistanceTo(double lat, double lon) {
    return DistanceCalculator.calculateDistance(this.lat, this.lon, lat, lon);
  }

  String getFormattedDistanceTo(double lat, double lon) {
    final distance = getDistanceTo(lat, lon);
    return DistanceCalculator.formatDistance(distance);
  }
} 