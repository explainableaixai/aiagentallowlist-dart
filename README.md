# aiagentallowlist (Dart)

An AI agent allow list answers a narrow question before an autonomous agent opens a page: is this the kind of page it should touch? A login form, a checkout, an upload dialog or a wiki edit screen can all do damage when an agent acts on them without a person watching. This package asks that question from Dart and returns a verdict you can act on.

The checks run against the [AI agent allow list with page-type verdicts](https://www.aiagentallowlist.com). Your code sends the URL the agent wants to visit. The service replies with what kind of page it is and whether policy allows the visit.

```bash
dart pub add aiagentallowlist
```

## Why page type, not just domain

Blocking whole domains is too blunt for agents. An agent researching a supplier should read `stripe.com/pricing`, but it should not land on `stripe.com/login` and start typing. The same domain holds pages with very different risk. The service knows, for a large set of domains, where the sensitive pages live: login, signup, checkout, account settings, upload and edit screens. It judges the URL against that knowledge and against a set of rules.

## The call

```dart
import 'package:aiagentallowlist/aiagentallowlist.dart';

final guard = AIAgentAllowlistClient(apiKey: key);

final r = await guard.check('https://github.com/login');
print(r['verdict']);   // "deny"
print(r['matched']);   // {layer: rules, id: login, ...}
```

`check` takes either a full URL or a bare domain.

- **With a full URL**, the response includes a `verdict` and a `matched` object naming the layer that decided (`rules` for built-in patterns, `page_type_db` for a page found in the database) and the `id` of the page type, such as `login`, `checkout`, `upload` or `wiki_edit`.
- **With a bare domain**, you get the domain record: `found`, the site `language`, and `page_types`, a map from page type to the known URL for that type on that site.

## Wiring it into an agent loop

Most agent frameworks expose a point just before a tool runs. That is where the check belongs. A browsing tool in Dart might look like this:

```dart
Future<String> browse(String url) async {
  final decision = await guard.check(url);
  if (decision['verdict'] == 'deny') {
    final why = (decision['matched'] as Map?)?['id'] ?? 'policy';
    return 'Blocked: this page is a $why page. Ask a person to do this step.';
  }
  return fetchPage(url);
}
```

Two details make this pattern work well:

- **Return the refusal to the model as text.** The agent reads it and can choose another route, or tell the user it needs help. Throwing an exception usually ends the run instead.
- **Treat anything other than an explicit allow as a stop.** New verdict values may appear over time. A guard that only blocks on `deny` would let them through.

## Planning ahead with domain records

Sometimes you want to know in advance where the risky pages are, for example to show a person which steps an agent will hand back. Look up the domain once:

```dart
final site = await guard.check('stripe.com');
if (site['found'] == true) {
  final pages = site['page_types'] as Map<String, dynamic>;
  print('Login lives at ${pages['login']}');
}
```

A domain that is not in the database comes back with `found: false` and an empty `page_types` map. Full URLs on such domains are still judged by the rule layer, so a `/login` or `/checkout` path is caught even on sites nobody has catalogued.

## Options

```dart
AIAgentAllowlistClient(
  apiKey: key,
  baseUrl: 'https://www.aiagentallowlist.com/api', // default
  httpClient: myClient,                            // optional
  timeout: const Duration(seconds: 10),            // default is 30
);
```

For agents, a shorter timeout is often right. If the guard cannot answer quickly, stop the step rather than let the agent proceed unchecked.

## Failure handling

| Situation | What you get |
|---|---|
| Empty key or URL | `ArgumentError`, no request sent |
| HTTP 401 or 403 | `AuthenticationException` (wrong key or quota used up) |
| HTTP 429 | `RateLimitException` |
| Other HTTP errors or non-JSON replies | `ApiException` with `statusCode` and `body` |
| Network timeout | `TimeoutException` from `dart:async` |

Decide up front whether your agent fails open or closed. For anything that can spend money or change data, closed is the safer default: no verdict, no visit.

## Caching verdicts

Agents revisit the same URLs within a task. Caching per task is safe and cheap:

```dart
final seen = <String, ApiResult>{};
Future<ApiResult> checkOnce(String url) async =>
    seen[url] ??= await guard.check(url);
```

Clear the map between tasks so a policy change on the service takes effect quickly.

## Logging decisions

Every verdict is worth a log line: the URL, the verdict, the matched page type and the task the agent was working on. Those records answer the first question anyone asks after an incident, which is what the agent tried to do. They also show which blocks happen most. A block that fires on every run of a workflow usually means the workflow needs a human step there, not a looser rule.

## Testing your guard

Inject a fake HTTP client and assert that your tool refuses what it should:

```dart
final fake = MockClient((_) async => http.Response(
    '{"verdict":"deny","matched":{"layer":"rules","id":"checkout"}}', 200));
final guard = AIAgentAllowlistClient(apiKey: 't', httpClient: fake);
expect(await browse('https://shop.example/checkout'), startsWith('Blocked'));
```

This test runs offline and fails loudly if someone later removes the check.

## Related guardrails

Page rules cover where an agent may act. Other layers cover what it may talk to and what it finds along the way:

- The same register helps teams [block AI apps across the enterprise](https://www.aitoolsblocklist.com), so agents stay away from unapproved chatbots and model APIs too.
- [Shadow AI detection tools](https://www.shadowaitools.com/detection-methodology.php) show which AI agents and assistants run in your network, found from logs you already have.
- [Check domain category](https://www.urlcategorizationdatabase.com/check-domain.php) data when a policy depends on what a site is about.

The approach lines up with the controls described in the OWASP Top 10 for LLM Applications (excessive agency) and the NIST AI Risk Management Framework, both of which call for limits on what automated agents may do without review.

## Same service, other languages

- [npm: aiagentallowlist](https://www.npmjs.com/package/aiagentallowlist)
- [PyPI: aiagentallowlist](https://pypi.org/project/aiagentallowlist/)

## License

MIT
