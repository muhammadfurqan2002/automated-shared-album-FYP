
import 'package:flutter/material.dart';

class SearchFilterSection extends StatefulWidget {
  final TextEditingController searchController;
  final String selectedSortOption;
  final Function(String) onSortOptionChanged;
  final int albumCount;
  final GlobalKey? searchBarKey;

  const SearchFilterSection({
    Key? key,
    required this.searchController,
    required this.selectedSortOption,
    required this.onSortOptionChanged,
    required this.albumCount,
    this.searchBarKey,
  }) : super(key: key);

  @override
  State<SearchFilterSection> createState() => _SearchFilterSectionState();
}

class _SearchFilterSectionState extends State<SearchFilterSection> {
  bool _isDropdownOpen = false;
  OverlayEntry? _overlayEntry;
  final GlobalKey _dropdownKey = GlobalKey();

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }

    setState(() {
      _isDropdownOpen = !_isDropdownOpen;
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    final RenderBox renderBox = _dropdownKey.currentContext!.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: offset.dy + renderBox.size.height+5,
        left: offset.dx,
        width: 120,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(5),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(5),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: const Text('Newest'),
                  onTap: () {
                    widget.onSortOptionChanged('Newest');
                    _toggleDropdown();
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Oldest'),
                  onTap: () {
                    widget.onSortOptionChanged('Oldest');
                    _toggleDropdown();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildFixedDropdown() {
    return SizedBox(
      width: 120,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: Container(
          key: _dropdownKey,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(5),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Text(
                widget.selectedSortOption,
                style: const TextStyle(fontSize: 16, color: Colors.black),
              ),
              const Spacer(),
              Icon(
                _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            key: widget.searchBarKey,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(5),
              color: Colors.white,
            ),
            child: TextField(
              controller: widget.searchController,
              decoration: const InputDecoration(
                hintText: 'Search albums',
                suffixIcon: Icon(Icons.search, color: Colors.grey),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFixedDropdown(),
              const SizedBox(width: 10),
              Text(
                '${widget.albumCount} Albums',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}