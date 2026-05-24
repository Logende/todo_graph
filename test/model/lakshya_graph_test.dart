import 'package:flutter_test/flutter_test.dart';
import 'package:lakshya/model/attachment.dart';
import 'package:lakshya/model/contribution.dart';
import 'package:lakshya/model/edge.dart';
import 'package:lakshya/model/filter.dart';
import 'package:lakshya/model/filter_preset.dart';
import 'package:lakshya/model/impact.dart';
import 'package:lakshya/model/lakshya_graph.dart';
import 'package:lakshya/model/node.dart';
import 'package:lakshya/model/node_notification_settings.dart';
import 'package:lakshya/model/node_relationship.dart';
import 'package:lakshya/model/node_status.dart';
import 'package:lakshya/model/settings.dart';

void main() {
  group('LakshyaGraph', () {
    test('empty graph has the current schema version', () {
      const g = LakshyaGraph.empty();
      expect(g.schemaVersion, equals(kCurrentSchemaVersion));
      expect(g.nodes, isEmpty);
      expect(g.edges, isEmpty);
      expect(g.relationships, isEmpty);
      expect(g.filterPresets, isEmpty);
      expect(g.settings, isNull);
    });

    test('roundtrips a fully populated graph through json', () {
      final original = LakshyaGraph(
        nodes: [
          Node(
            id: 'n-1',
            title: 'Health',
            status: NodeStatus.alwaysOnBackground,
            createdAt: DateTime.utc(2026, 5, 24),
          ),
          Node(
            id: 'n-2',
            title: 'Respond to Watzenborn',
            description: 'Urgent deadline',
            status: NodeStatus.oneTime(),
            deadline: DateTime.utc(2026, 5, 26, 17),
            impact: Impact.high,
            createdAt: DateTime.utc(2026, 5, 24),
            updatedAt: DateTime.utc(2026, 5, 24, 11),
            attachments: const [
              UrlAttachment(url: 'mailto:watzenborn@example.com'),
            ],
            notificationOverride: const NodeNotificationSettings(
              deadlineLeadTimeHours: 6,
              notifyOnPeriodicReopen: true,
            ),
          ),
        ],
        edges: const [
          Edge(
            id: 'e-1',
            childId: 'n-2',
            parentId: 'n-1',
            contribution: Contribution.helpful,
          ),
        ],
        relationships: const [
          NodeRelationship(
            id: 'r-1',
            fromNodeId: 'n-2',
            toNodeId: 'n-1',
            kind: RelationshipKind.moreImportantThan,
          ),
        ],
        filterPresets: const [
          FilterPreset(
            id: 'fp-1',
            title: 'Work',
            iconName: 'work',
            ordering: 0,
            filter: Filter(
              ancestorGoalIds: ['n-1'],
              contribution: FilterContribution.mandatory,
              completionKinds: ['periodic', 'one_time'],
              activationKinds: ['always_active'],
              onlyOngoing: true,
              onlyLeaves: true,
              freeText: 'urgent',
            ),
          ),
        ],
        settings: const Settings(
          defaultDeadlineLeadTimeHours: 24,
          notifyOnPeriodicReopenByDefault: true,
          rootNodeId: 'n-1',
          urgentWindowDays: 5,
        ),
      );

      final round = LakshyaGraph.fromJson(original.toJson());

      expect(round, equals(original));
    });

    test('omits empty optional collections from json', () {
      const g = LakshyaGraph.empty();
      final json = g.toJson();
      expect(json.containsKey('relationships'), isFalse);
      expect(json.containsKey('filterPresets'), isFalse);
      expect(json.containsKey('settings'), isFalse);
      expect(json['nodes'], isEmpty);
      expect(json['edges'], isEmpty);
    });
  });
}
