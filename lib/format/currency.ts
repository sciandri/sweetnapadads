const wholeDollarFormatter = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});

const fractionalDollarFormatter = new Intl.NumberFormat("en-US", {
  style: "currency",
  currency: "USD",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

export function formatCurrency(cents: number): string {
  if (!Number.isSafeInteger(cents)) {
    throw new TypeError("Currency values must be safe integer cents.");
  }

  const formatter =
    cents % 100 === 0 ? wholeDollarFormatter : fractionalDollarFormatter;

  return formatter.format(cents / 100);
}
