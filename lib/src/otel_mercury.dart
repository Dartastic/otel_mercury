// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_mercury_suppression.dart';

const _tracerName = 'dartastic_otel_libs_mercury';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

class MercuryResult {
  /// Creates a result.
  const MercuryResult({
    this.accountId,
    this.transactionId,
    this.paymentMethod,
    this.kind,
    this.status,
    this.amountMinor,
    this.currency,
    this.statusCode,
  });

  final String? accountId;
  final String? transactionId;

  /// `ach`, `wire`, `check`, `internal`, `card`, `treasury_sweep`.
  final String? paymentMethod;

  /// Transaction kind: `payment` / `transfer` / `interest` /
  /// `dividend` / `card_transaction` / `fee`.
  final String? kind;

  /// `pending` / `posted` / `cancelled` / `failed`.
  final String? status;
  final int? amountMinor;
  final String? currency;
  final int? statusCode;
}

/// What a traced call returned: the value for the caller plus fields
/// recorded on the span.
class MercuryCallResult<T> {
  /// Creates a call result.
  const MercuryCallResult({required this.value, this.result});

  /// The value returned to the caller.
  final T value;
  final MercuryResult? result;
}

/// Wraps a Mercury API call in a CLIENT span. [operation] is the
/// route like `accounts.list`, `accounts.transactions.list`,
/// `accounts.transactions.send`, `statements.get`.
Future<T> tracedMercury<T>({
  required String operation,
  required Future<MercuryCallResult<T>> Function() invoke,
}) async {
  if (mercuryInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'mercury',
    'rpc.method': operation,
  };

  final span = _tracer().startSpan(
    'mercury $operation',
    kind: SpanKind.client,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.accountId != null) {
        extras.add(OTelAPI.attributeString(
          'mercury.account.id',
          r.result!.accountId!,
        ));
      }
      if (r.result!.transactionId != null) {
        extras.add(OTelAPI.attributeString(
          'mercury.transaction.id',
          r.result!.transactionId!,
        ));
      }
      if (r.result!.paymentMethod != null) {
        extras.add(OTelAPI.attributeString(
          'mercury.payment_method',
          r.result!.paymentMethod!,
        ));
      }
      if (r.result!.kind != null) {
        extras.add(OTelAPI.attributeString(
          'mercury.transaction.kind',
          r.result!.kind!,
        ));
      }
      if (r.result!.status != null) {
        extras.add(OTelAPI.attributeString(
          'mercury.status',
          r.result!.status!,
        ));
        if (r.result!.status == 'failed' || r.result!.status == 'cancelled') {
          span.setStatus(
            SpanStatusCode.Error,
            'Mercury status ${r.result!.status}',
          );
        }
      }
      if (r.result!.amountMinor != null) {
        extras.add(OTelAPI.attributeInt(
          'mercury.amount.minor',
          r.result!.amountMinor!,
        ));
      }
      if (r.result!.currency != null) {
        extras.add(OTelAPI.attributeString(
          'mercury.currency',
          r.result!.currency!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTelAPI.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Mercury HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTelAPI.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
