module MoneyHelper
  # Always two decimals ("18500.00"), and always a string, because JSON floats and money don't mix.
  def money(amount)
    format('%.2f', amount) unless amount.nil?
  end
end
