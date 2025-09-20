import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:guidey1/quiz/quiz_page.dart';
import 'assistant_screen.dart';
import 'career_search_page.dart';
import 'home_screen.dart';
import 'jobs_screen.dart';


class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  int _selectedIndex = 0;

  final List<Widget> pages = [
    const HomeScreen(),
    QuizScreen(),
    CareerSearchPage(),
    AssistantScreen(),
    JobsScreen(),
  ];


  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Color(0xFF8E2DE2),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.brain),
            label: 'Quiz',
          ),
          BottomNavigationBarItem(
            icon: Icon(FontAwesomeIcons.map),
            label: 'Roadmap',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Assistant',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_repair_service_rounded),
            label: 'Jobs',
          ),
        ],
      ),
    );
  }
}