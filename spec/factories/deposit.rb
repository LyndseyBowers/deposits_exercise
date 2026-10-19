# frozen_string_literal: true

FactoryBot.define do
  factory :deposit do
    tradeline
    amount { 100.00 }
    deposit_date { Date.current + 7 }
  end
end
