export function formatPrice(cents: number, currency = 'EUR', locale?: string) {
  return new Intl.NumberFormat(locale ?? 'en-IE', {
    style: 'currency',
    currency,
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(cents / 100);
}
