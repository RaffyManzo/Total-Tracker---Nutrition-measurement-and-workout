# Target model 0.1.0 — theo.2

Logical patch: `0.1.0_01_theo`
Application version: `0.1.0+14`
Model version: `target-model-0.1.0-theo.2`

This release replaces Harris–Benedict with Mifflin–St Jeor, replaces the primary fixed step coefficient with a weight-and-distance estimate, uses daily weight medians and Theil–Sen trend, fixes the weight-energy prior at 7700 kcal/kg, and updates default macros.

## Component-wise activity fallback

Steps and completed workouts are independent components:

- recorded steps + recorded workout: `actual`;
- recorded steps + workout fallback: `partially_provisional`;
- step fallback + recorded workout: `partially_provisional`;
- step fallback + workout fallback: `provisional`;
- no fallback and no data: `unavailable`.

A legacy `profile_estimate` setting is interpreted as component-wise fallback. It never replaces a component that has been recorded.

## Persistence and migration

No ObjectBox schema change is required. Historical target snapshots are not mass-recalculated. New snapshots include the model version and fallback/guardrail state in `targetSourceHash`. Legacy macro-custom settings remain identifiable and are not silently converted to the new percentage-based fat setting.

## User-configurable step goal

The daily step goal is configured by the user. The compatibility default is 8000, but it is not a physiological threshold and is not classified as `IN STALLO`. It is used as the step fallback only when recorded daily steps are missing.

## Workout calorie input contract

The nutrition model does not estimate calories from workout exercises, sets, heart rate, MET corrections, or other workout internals in this patch. Each completed workout exposes `estimated_active_calories`; the day sums those non-negative values. The current persistence mapping is `WorkoutSessionEntity.estimatedKcalBurned`. A profile-level workout fallback is applied only when no completed workout value exists for the day. Designing the workout calorie model remains outside `0.1.0_01_theo`.

## Stalled parameters

The following remain operational but explicitly `IN STALLO`: the 1.10 base factor, composition activation threshold, blending and confidence thresholds, and TDEE guardrails.

The machine-readable source registry is `assets/data/target_model_0_1_0_theo_2_sources.json`.
