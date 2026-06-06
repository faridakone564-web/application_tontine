import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../widgets/custom_widgets.dart';
import 'home_screen.dart';
import 'mes_groups_screen.dart';
import 'discover_screen.dart';
import 'mes_paiements_screen.dart';
import 'beneficiary_screen.dart';
import 'profile_screen.dart';

class MainNav extends StatefulWidget {
  const MainNav({super.key});

  @override
  State<MainNav> createState() => _MainNavState();
}

class _MainNavState extends State<MainNav> {
  int _currentIndex = 0;

  static final List<Widget> _pages = <Widget>[
    const HomeScreen(),
    const MesGroupsScreen(),
    const DiscoverScreen(),
    const MesPaiementsScreen(),
    const BeneficiaryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
