# OpenNutrition progressive search and network policy

## Search ordering

The ingredient search renders sources progressively:

1. personal/imported ingredients;
2. Open Food Facts;
3. OpenNutrition.

OpenNutrition never blocks already available Open Food Facts results. Each source has an independent loading and error state. Stale asynchronous searches are discarded through a generation identifier.

## Time limits

- local search: 8 seconds;
- Open Food Facts: up to 10 minutes overall;
- OpenNutrition, including on-device translation: up to 10 minutes overall.

Both external sources retry transient network/server failures 20 times after the initial attempt, using bounded backoff and deterministic jitter. Permanent failures (configuration, integrity, unsafe redirects, incompatible schema, and non-retryable HTTP 4xx responses) fail immediately. A timeout does not remove results already rendered by earlier sources.

## Network policy

The user can select one of three OpenNutrition policies:

- Wi-Fi only;
- mobile data only;
- Wi-Fi and mobile data.

Ethernet is treated as Wi-Fi. The policy is enforced in the unified search service before the static index or legacy remote gateway is contacted. Connection classification is only a preventive policy check: all network operations still require timeout and error handling because a reported connection type does not guarantee Internet access.

## Back navigation

A priority child `BackButtonDispatcher` intercepts Android platform back events before GoRouter can close the root route. Programmatic `context.pop` operations remain unaffected. A back action with no route to pop returns to the preferred dashboard; closing from that dashboard still requires explicit double-back confirmation.
