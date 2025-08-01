
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../models/highlight.dart';
import '../reel_screen.dart';

class HighlightReelList extends StatefulWidget {
  final List<ReelModel> reelsData;
  final ScrollController scrollController;
  final bool isLoading;

  const HighlightReelList({
    Key? key,
    required this.reelsData,
    required this.scrollController,
    required this.isLoading,
  }) : super(key: key);

  @override
  _HighlightReelListState createState() => _HighlightReelListState();
}

class _HighlightReelListState extends State<HighlightReelList>
    with AutomaticKeepAliveClientMixin<HighlightReelList> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: ListView.builder(
        key: const PageStorageKey('highlightReelList'),
        controller: widget.scrollController,
        itemCount: widget.reelsData.length + (widget.isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index < widget.reelsData.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12),
              child: SizedBox(
                height: SingleReelWidget.imageHeight,
                child: SingleReelWidget(reel: widget.reelsData[index]),
              ),
            );
          } else {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
        },
      ),
    );
  }
}
