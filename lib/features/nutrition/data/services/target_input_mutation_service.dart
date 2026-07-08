import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

import '../entities/nutrition_tracking_entities.dart';
import 'target_input_change_bus.dart';

class TargetInputMutationService {
  const TargetInputMutationService._();

  static TargetInvalidationEntity enqueueInCurrentTransaction(
    Store store, {
    required TargetInputChangeKind kind,
    required String fromDateKey,
    String? toDateKey,
    required String reasonCode,
    String? sourceEntityUuid,
    int? sourceRevision,
  }) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final TargetInvalidationEntity entity = TargetInvalidationEntity(
      uuid: const Uuid().v4(),
      fromDateKey: fromDateKey,
      toDateKey: toDateKey ?? '',
      kindCode: kind.name,
      reasonCode: reasonCode,
      sourceEntityUuid: sourceEntityUuid ?? '',
      sourceRevision: sourceRevision ?? now,
      statusCode: 'pending',
      createdAtEpochMs: now,
      updatedAtEpochMs: now,
    );
    entity.id = store.box<TargetInvalidationEntity>().put(entity);
    return entity;
  }

  static void publishAfterCommit({
    required TargetInputChangeKind kind,
    required String fromDateKey,
    String? toDateKey,
    required String reasonCode,
    String? sourceEntityUuid,
    int? sourceRevision,
  }) {
    TargetInputChangeBus.publishInput(
      TargetInputChanged(
        kind: kind,
        fromDateKey: fromDateKey,
        toDateKey: toDateKey,
        reasonCode: reasonCode,
        sourceRevision: sourceRevision ?? DateTime.now().millisecondsSinceEpoch,
        sourceEntityUuid: sourceEntityUuid,
      ),
    );
  }
}
