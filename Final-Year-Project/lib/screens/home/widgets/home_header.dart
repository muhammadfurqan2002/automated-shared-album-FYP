import 'package:flutter/material.dart';
import 'package:fyp/screens/searchmore/searchmore.dart';

class AlbumsHeader extends StatelessWidget {
  const AlbumsHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          const Text(
            'Albums',
            style: TextStyle(color: Colors.black, fontSize: 18,fontWeight: FontWeight.w500),
          ),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchMoreScreen()),
              );
            },
            child: const Text(
              'See more',
              style: TextStyle(color: Colors.blue, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
