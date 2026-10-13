type LogLevel = "info" | "warn" | "error";

interface PaymentLogPayload {
  level: LogLevel;
  service: "evos-payment";
  function: string;
  step: string;
  ts: string;
  [key: string]: unknown;
}

function emit(payload: PaymentLogPayload): void {
  const line = JSON.stringify(payload);
  if (payload.level === "error") {
    console.error(line);
  } else if (payload.level === "warn") {
    console.warn(line);
  } else {
    console.log(line);
  }
}

export function logPayment(
  functionName: string,
  step: string,
  data: Record<string, unknown> = {},
  level: LogLevel = "info",
): void {
  emit({
    level,
    service: "evos-payment",
    function: functionName,
    step,
    ts: new Date().toISOString(),
    ...data,
  });
}

export function logPaymentError(
  functionName: string,
  step: string,
  error: unknown,
  data: Record<string, unknown> = {},
): void {
  const message = error instanceof Error ? error.message : String(error);
  emit({
    level: "error",
    service: "evos-payment",
    function: functionName,
    step,
    ts: new Date().toISOString(),
    error: message,
    ...data,
  });
}
