class PhoneNormalizer
  # Geographic codes from Google's libphonenumber AR metadata:
  # https://github.com/google/libphonenumber/blob/master/resources/PhoneNumberMetadata.xml
  AREA_CODES = JSON.parse(Rails.root.join("config/argentina_area_codes.json").read).freeze

  def self.normalize(value, area_code: "11", strict: false)
    return nil if value.blank?

    digits = value.to_s.gsub(/\D/, "").sub(/\A00/, "")
    national = digits
    national = national.delete_prefix("54") if national.start_with?("54") && national.length > 10
    national = national.delete_prefix("9") if national.length == 11
    national = national.delete_prefix("0")

    if national.start_with?("15")
      national = "#{area_code}#{national.delete_prefix('15')}"
    elsif national.length == 12
      code = AREA_CODES.find { |candidate| national.start_with?("#{candidate}15") }
      national = "#{code}#{national.delete_prefix("#{code}15")}" if code
    elsif national.length == 10 - area_code.to_s.length
      national = "#{area_code}#{national}"
    end

    valid = national.match?(/\A[1-3]\d{9}\z/) && AREA_CODES.any? { |code| national.start_with?(code) }
    return "549#{national}" if valid

    strict ? nil : digits.presence
  end
end
