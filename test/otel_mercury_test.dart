// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_mercury/otel_mercury.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_mercury-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('ACH send records method + kind + status', () async {
    await tracedMercury<String>(
      operation: 'accounts.transactions.send',
      invoke: () async => const MercuryCallResult(
        value: 'ok',
        result: MercuryResult(
          accountId: 'acc-1',
          transactionId: 'txn-1',
          paymentMethod: 'ach',
          kind: 'payment',
          status: 'pending',
          amountMinor: 250000,
          currency: 'USD',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(
      spans.findSpanByName('mercury accounts.transactions.send')!,
    );
    expect(a['mercury.payment_method'], 'ach');
    expect(a['mercury.transaction.kind'], 'payment');
    expect(a['mercury.status'], 'pending');
  });

  test('failed status maps to span error', () async {
    await tracedMercury<String>(
      operation: 'accounts.transactions.send',
      invoke: () async => const MercuryCallResult(
        value: 'ok',
        result: MercuryResult(status: 'failed'),
      ),
    );
    expect(
      spans.findSpanByName('mercury accounts.transactions.send')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutMercuryInstrumentationAsync(() async {
      await tracedMercury<String>(
        operation: 'accounts.list',
        invoke: () async => const MercuryCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('mercury '), isEmpty);
  });
}
