// Matches PricingConstants.taxRate in
// macos/OurWish/OurWish/Views/Shared/CurrencyFormatting.swift.
export const TAX_RATE = 0.0875

const formatter = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' })

export function formatCurrency(value: number): string {
  return formatter.format(value)
}
