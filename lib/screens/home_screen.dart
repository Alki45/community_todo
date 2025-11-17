import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'tabs/groups_tab.dart';
import 'tabs/home_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/statistics_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  static final List<Widget> _tabs = const [
    HomeTab(key: ValueKey('home_tab')),
    GroupsTab(key: ValueKey('groups_tab')),
    StatisticsTab(key: ValueKey('stats_tab')),
    ProfileTab(key: ValueKey('profile_tab')),
  ];

  static const List<NavigationDestination> _destinations = [
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_alt_outlined),
      selectedIcon: Icon(Icons.people_alt),
      label: 'Groups',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      selectedIcon: Icon(Icons.bar_chart),
      label: 'Statistics',
    ),
    NavigationDestination(
      icon: Icon(Icons.person_outline),
      selectedIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  void _setIndex(int value) {
    if (value == _currentIndex) {
      return;
    }
    setState(() {
      _currentIndex = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: _setIndex,
                  destinations: _destinations
                      .map(
                        (destination) => NavigationRailDestination(
                          icon: destination.icon,
                          selectedIcon: destination.selectedIcon,
                          label: Text(destination.label),
                        ),
                      )
                      .toList(),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Provider<ValueChanged<int>>.value(
                    value: _setIndex,
                    child: IndexedStack(index: _currentIndex, children: _tabs),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: Provider<ValueChanged<int>>.value(
            value: _setIndex,
            child: IndexedStack(index: _currentIndex, children: _tabs),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _setIndex,
            destinations: _destinations,
          ),
        );
      },
    );
  }
}
