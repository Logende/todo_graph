// GENERATED FILE — do not edit by hand.
// Source of truth: schema/lakshya.schema.json
// Regenerate via MetaConfigurator + QuickType (Dart) and overwrite this file.
// To parse this JSON data, do
//
//     final lakshyaGraph = lakshyaGraphFromJson(jsonString);

// ignore_for_file: constant_identifier_names

import 'dart:convert';

LakshyaGraph lakshyaGraphFromJson(String str) =>
    LakshyaGraph.fromJson(json.decode(str));

String lakshyaGraphToJson(LakshyaGraph data) => json.encode(data.toJson());

///Full Lakshya graph document. A single JSON file stored in the app data directory holding
///every node, every edge, every manual priority pin, every dashboard filter preset, and
///global settings.
class LakshyaGraph {
  List<EdgeElement> edges;
  List<FilterPresetElement>? filterPresets;
  List<NodeElement> nodes;
  List<PriorityPinElement>? priorityPins;

  ///Schema version of this document. Bumped on breaking changes so the repository layer can
  ///run migrations.
  int schemaVersion;
  Settings? settings;

  LakshyaGraph({
    required this.edges,
    this.filterPresets,
    required this.nodes,
    this.priorityPins,
    required this.schemaVersion,
    this.settings,
  });

  factory LakshyaGraph.fromJson(Map<String, dynamic> json) => LakshyaGraph(
    edges: List<EdgeElement>.from(
      json["edges"].map((x) => EdgeElement.fromJson(x)),
    ),
    filterPresets: json["filterPresets"] == null
        ? []
        : List<FilterPresetElement>.from(
            json["filterPresets"]!.map((x) => FilterPresetElement.fromJson(x)),
          ),
    nodes: List<NodeElement>.from(
      json["nodes"].map((x) => NodeElement.fromJson(x)),
    ),
    priorityPins: json["priorityPins"] == null
        ? []
        : List<PriorityPinElement>.from(
            json["priorityPins"]!.map((x) => PriorityPinElement.fromJson(x)),
          ),
    schemaVersion: json["schemaVersion"],
    settings: json["settings"] == null
        ? null
        : Settings.fromJson(json["settings"]),
  );

  Map<String, dynamic> toJson() => {
    "edges": List<dynamic>.from(edges.map((x) => x.toJson())),
    "filterPresets": filterPresets == null
        ? []
        : List<dynamic>.from(filterPresets!.map((x) => x.toJson())),
    "nodes": List<dynamic>.from(nodes.map((x) => x.toJson())),
    "priorityPins": priorityPins == null
        ? []
        : List<dynamic>.from(priorityPins!.map((x) => x.toJson())),
    "schemaVersion": schemaVersion,
    "settings": settings?.toJson(),
  };
}

///Directed contribution from a child node to a parent goal. A node can have many parents;
///the same child appears in multiple edges.
class EdgeElement {
  ///The lower-level node that contributes upward.
  String childId;

  ///Mandatory: parent is not fulfillable without this child. Helpful: child assists but is
  ///not required.
  EdgeContribution contribution;
  String id;

  ///The higher-level goal being contributed to.
  String parentId;

  EdgeElement({
    required this.childId,
    required this.contribution,
    required this.id,
    required this.parentId,
  });

  factory EdgeElement.fromJson(Map<String, dynamic> json) => EdgeElement(
    childId: json["childId"],
    contribution: edgeContributionValues.map[json["contribution"]]!,
    id: json["id"],
    parentId: json["parentId"],
  );

  Map<String, dynamic> toJson() => {
    "childId": childId,
    "contribution": edgeContributionValues.reverse[contribution],
    "id": id,
    "parentId": parentId,
  };
}

///Mandatory: parent is not fulfillable without this child. Helpful: child assists but is
///not required.
enum EdgeContribution { HELPFUL, MANDATORY }

final edgeContributionValues = EnumValues({
  "helpful": EdgeContribution.HELPFUL,
  "mandatory": EdgeContribution.MANDATORY,
});

///Dashboard tile. Tapping the tile opens a list or graph view pre-filtered by this filter.
class FilterPresetElement {
  Filter filter;

  ///Optional Material icon name for the tile face.
  String? iconName;
  String id;

  ///Sort order of tiles in the dashboard.
  int? ordering;
  String title;

  FilterPresetElement({
    required this.filter,
    this.iconName,
    required this.id,
    this.ordering,
    required this.title,
  });

  factory FilterPresetElement.fromJson(Map<String, dynamic> json) =>
      FilterPresetElement(
        filter: Filter.fromJson(json["filter"]),
        iconName: json["iconName"],
        id: json["id"],
        ordering: json["ordering"],
        title: json["title"],
      );

  Map<String, dynamic> toJson() => {
    "filter": filter.toJson(),
    "iconName": iconName,
    "id": id,
    "ordering": ordering,
    "title": title,
  };
}

///Composable filter spec used by the graph view, the todo list view, and dashboard tiles.
class Filter {
  ///Keep only nodes that are descendants of at least one of these goals.
  List<String>? ancestorGoalIds;

  ///Restrict to incoming edges of this contribution kind when computing descendants.
  FilterContribution? contribution;

  ///Case-insensitive substring match against node title and description.
  String? freeText;

  ///Keep only nodes that are leaves within the filtered subgraph.
  bool? onlyLeaves;

  ///Keep only currently-actionable nodes: one_time not completed, n_times with completedCount
  ///< targetCount, periodic past its next due date, temporarily_active inside its window and
  ///not completed.
  bool? onlyOngoing;

  ///Keep only nodes whose status type is one of these.
  List<TypeElement>? statusTypes;

  Filter({
    this.ancestorGoalIds,
    this.contribution,
    this.freeText,
    this.onlyLeaves,
    this.onlyOngoing,
    this.statusTypes,
  });

  factory Filter.fromJson(Map<String, dynamic> json) => Filter(
    ancestorGoalIds: json["ancestorGoalIds"] == null
        ? []
        : List<String>.from(json["ancestorGoalIds"]!.map((x) => x)),
    contribution: filterContributionValues.map[json["contribution"]]!,
    freeText: json["freeText"],
    onlyLeaves: json["onlyLeaves"],
    onlyOngoing: json["onlyOngoing"],
    statusTypes: json["statusTypes"] == null
        ? []
        : List<TypeElement>.from(
            json["statusTypes"]!.map((x) => typeElementValues.map[x]!),
          ),
  );

  Map<String, dynamic> toJson() => {
    "ancestorGoalIds": ancestorGoalIds == null
        ? []
        : List<dynamic>.from(ancestorGoalIds!.map((x) => x)),
    "contribution": filterContributionValues.reverse[contribution],
    "freeText": freeText,
    "onlyLeaves": onlyLeaves,
    "onlyOngoing": onlyOngoing,
    "statusTypes": statusTypes == null
        ? []
        : List<dynamic>.from(
            statusTypes!.map((x) => typeElementValues.reverse[x]),
          ),
  };
}

///Restrict to incoming edges of this contribution kind when computing descendants.
enum FilterContribution { ANY, HELPFUL, MANDATORY }

final filterContributionValues = EnumValues({
  "any": FilterContribution.ANY,
  "helpful": FilterContribution.HELPFUL,
  "mandatory": FilterContribution.MANDATORY,
});

enum TypeElement { ALWAYS_ON, N_TIMES, ONE_TIME, PERIODIC, TEMPORARILY_ACTIVE }

final typeElementValues = EnumValues({
  "always_on": TypeElement.ALWAYS_ON,
  "n_times": TypeElement.N_TIMES,
  "one_time": TypeElement.ONE_TIME,
  "periodic": TypeElement.PERIODIC,
  "temporarily_active": TypeElement.TEMPORARILY_ACTIVE,
});

class NodeElement {
  List<AttachmentElement>? attachments;
  DateTime createdAt;

  ///Hard deadline for this node. Drives deadline reminders.
  DateTime? deadline;
  String? description;
  String id;
  NotificationOverride? notificationOverride;

  ///User-assigned positive impact estimate. Combined with priority for the default ordering.
  double? positiveImpact;

  ///User-assigned priority score. Higher ranks earlier in the default ordering.
  double? priority;
  Status status;
  String title;
  DateTime? updatedAt;

  NodeElement({
    this.attachments,
    required this.createdAt,
    this.deadline,
    this.description,
    required this.id,
    this.notificationOverride,
    this.positiveImpact,
    this.priority,
    required this.status,
    required this.title,
    this.updatedAt,
  });

  factory NodeElement.fromJson(Map<String, dynamic> json) => NodeElement(
    attachments: json["attachments"] == null
        ? []
        : List<AttachmentElement>.from(
            json["attachments"]!.map((x) => AttachmentElement.fromJson(x)),
          ),
    createdAt: DateTime.parse(json["createdAt"]),
    deadline: json["deadline"] == null
        ? null
        : DateTime.parse(json["deadline"]),
    description: json["description"],
    id: json["id"],
    notificationOverride: json["notificationOverride"] == null
        ? null
        : NotificationOverride.fromJson(json["notificationOverride"]),
    positiveImpact: json["positiveImpact"]?.toDouble(),
    priority: json["priority"]?.toDouble(),
    status: Status.fromJson(json["status"]),
    title: json["title"],
    updatedAt: json["updatedAt"] == null
        ? null
        : DateTime.parse(json["updatedAt"]),
  );

  Map<String, dynamic> toJson() => {
    "attachments": attachments == null
        ? []
        : List<dynamic>.from(attachments!.map((x) => x.toJson())),
    "createdAt": createdAt.toIso8601String(),
    "deadline": deadline?.toIso8601String(),
    "description": description,
    "id": id,
    "notificationOverride": notificationOverride?.toJson(),
    "positiveImpact": positiveImpact,
    "priority": priority,
    "status": status.toJson(),
    "title": title,
    "updatedAt": updatedAt?.toIso8601String(),
  };
}

///Discriminated union of attachment kinds linked to a node.
///
///Fires a reminder at the given moment, independent of any deadline on the node.
class AttachmentElement {
  String? label;
  AttachmentType type;
  String? url;
  double? latitude;
  double? longitude;
  DateTime? triggerAt;

  AttachmentElement({
    this.label,
    required this.type,
    this.url,
    this.latitude,
    this.longitude,
    this.triggerAt,
  });

  factory AttachmentElement.fromJson(Map<String, dynamic> json) =>
      AttachmentElement(
        label: json["label"],
        type: attachmentTypeValues.map[json["type"]]!,
        url: json["url"],
        latitude: json["latitude"]?.toDouble(),
        longitude: json["longitude"]?.toDouble(),
        triggerAt: json["triggerAt"] == null
            ? null
            : DateTime.parse(json["triggerAt"]),
      );

  Map<String, dynamic> toJson() => {
    "label": label,
    "type": attachmentTypeValues.reverse[type],
    "url": url,
    "latitude": latitude,
    "longitude": longitude,
    "triggerAt": triggerAt?.toIso8601String(),
  };
}

enum AttachmentType { GEO_LOCATION, TIME_TRIGGER, URL }

final attachmentTypeValues = EnumValues({
  "geo_location": AttachmentType.GEO_LOCATION,
  "time_trigger": AttachmentType.TIME_TRIGGER,
  "url": AttachmentType.URL,
});

///Per-node override of the global notification defaults. Unset fields fall back to global
///Settings.
class NotificationOverride {
  int? deadlineLeadTimeHours;
  bool? notifyOnPeriodicReopen;

  NotificationOverride({
    this.deadlineLeadTimeHours,
    this.notifyOnPeriodicReopen,
  });

  factory NotificationOverride.fromJson(Map<String, dynamic> json) =>
      NotificationOverride(
        deadlineLeadTimeHours: json["deadlineLeadTimeHours"],
        notifyOnPeriodicReopen: json["notifyOnPeriodicReopen"],
      );

  Map<String, dynamic> toJson() => {
    "deadlineLeadTimeHours": deadlineLeadTimeHours,
    "notifyOnPeriodicReopen": notifyOnPeriodicReopen,
  };
}

///Discriminated union of status kinds. The 'type' field selects the variant.
///
///Background goal with no completion state. Used for top-level life areas like 'Health' or
///'Work'.
///
///Task that is completed exactly once and then permanently done.
///
///Task that must be completed a fixed number of times. Tracks remaining completions.
///
///Task that re-opens a fixed number of days AFTER the last completion. Completing late
///pushes the next due date forward; the cadence is relative, not absolute.
///
///Task or goal that is only active during a bounded time window. Outside the window it is
///inactive regardless of completion.
class Status {
  TypeElement type;

  ///Absent while open; set on completion.
  DateTime? completedAt;
  int? completedCount;

  ///Absent if never completed (task is open immediately).
  DateTime? lastCompletedAt;
  int? targetCount;

  ///Days to wait after a completion before this task is considered open again.
  int? intervalDaysSinceLastCompletion;
  DateTime? activeFrom;
  DateTime? activeUntil;

  Status({
    required this.type,
    this.completedAt,
    this.completedCount,
    this.lastCompletedAt,
    this.targetCount,
    this.intervalDaysSinceLastCompletion,
    this.activeFrom,
    this.activeUntil,
  });

  factory Status.fromJson(Map<String, dynamic> json) => Status(
    type: typeElementValues.map[json["type"]]!,
    completedAt: json["completedAt"] == null
        ? null
        : DateTime.parse(json["completedAt"]),
    completedCount: json["completedCount"],
    lastCompletedAt: json["lastCompletedAt"] == null
        ? null
        : DateTime.parse(json["lastCompletedAt"]),
    targetCount: json["targetCount"],
    intervalDaysSinceLastCompletion: json["intervalDaysSinceLastCompletion"],
    activeFrom: json["activeFrom"] == null
        ? null
        : DateTime.parse(json["activeFrom"]),
    activeUntil: json["activeUntil"] == null
        ? null
        : DateTime.parse(json["activeUntil"]),
  );

  Map<String, dynamic> toJson() => {
    "type": typeElementValues.reverse[type],
    "completedAt": completedAt?.toIso8601String(),
    "completedCount": completedCount,
    "lastCompletedAt": lastCompletedAt?.toIso8601String(),
    "targetCount": targetCount,
    "intervalDaysSinceLastCompletion": intervalDaysSinceLastCompletion,
    "activeFrom": activeFrom?.toIso8601String(),
    "activeUntil": activeUntil?.toIso8601String(),
  };
}

///Hard manual override declaring one node ranks above another, regardless of
///priority/impact scores.
class PriorityPinElement {
  String higherId;
  String lowerId;

  PriorityPinElement({required this.higherId, required this.lowerId});

  factory PriorityPinElement.fromJson(Map<String, dynamic> json) =>
      PriorityPinElement(higherId: json["higherId"], lowerId: json["lowerId"]);

  Map<String, dynamic> toJson() => {"higherId": higherId, "lowerId": lowerId};
}

class Settings {
  ///Default hours before a deadline at which a reminder fires. Nodes may override via
  ///notificationOverride.
  int? defaultDeadlineLeadTimeHours;

  ///Whether a notification fires when a periodic task becomes open again, unless the node
  ///overrides it.
  bool? notifyOnPeriodicReopenByDefault;

  ///ID of the 'all goals achieved' top-level node. The graph engine treats this as the
  ///universal ancestor when computing descendant filters with no ancestorGoalIds set.
  String? rootNodeId;

  Settings({
    this.defaultDeadlineLeadTimeHours,
    this.notifyOnPeriodicReopenByDefault,
    this.rootNodeId,
  });

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
    defaultDeadlineLeadTimeHours: json["defaultDeadlineLeadTimeHours"],
    notifyOnPeriodicReopenByDefault: json["notifyOnPeriodicReopenByDefault"],
    rootNodeId: json["rootNodeId"],
  );

  Map<String, dynamic> toJson() => {
    "defaultDeadlineLeadTimeHours": defaultDeadlineLeadTimeHours,
    "notifyOnPeriodicReopenByDefault": notifyOnPeriodicReopenByDefault,
    "rootNodeId": rootNodeId,
  };
}

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}
