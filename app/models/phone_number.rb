class PhoneNumber
  def self.normalize(value)
    PhoneNormalizer.normalize(value).to_s
  end

  def self.lookup_values(value)
    normalized = normalize(value)
    original = value.to_s.strip.gsub(/[^\d+]/, "")
    original_digits = original.delete_prefix("+")
    values = [ normalized, normalized.present? ? "+#{normalized}" : nil, original, original_digits ]

    if normalized.start_with?("549")
      without_mobile_prefix = "54#{normalized.delete_prefix("549")}"
      values << without_mobile_prefix
      values << "+#{without_mobile_prefix}"
    elsif normalized.start_with?("54")
      with_mobile_prefix = "549#{normalized.delete_prefix("54")}"
      values << with_mobile_prefix
      values << "+#{with_mobile_prefix}"
    end

    values.compact_blank.uniq
  end

end
