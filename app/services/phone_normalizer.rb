class PhoneNormalizer
  def self.normalize(value)
    return nil if value.blank?

    phone = value.to_s.gsub(/[^\d]/, "")
    phone = phone.sub(/\A00/, "")
    return nil if phone.blank?

    if phone.start_with?("549")
      phone
    elsif phone.start_with?("54")
      national_number = phone.delete_prefix("54")
      national_number.length == 10 ? "549#{national_number}" : phone
    elsif phone.start_with?("15") && phone.length == 10
      "54911#{phone.delete_prefix("15")}"
    elsif phone.start_with?("9") && phone.length >= 10
      "54#{phone}"
    elsif phone.start_with?("11") || phone.length == 10
      "549#{phone}"
    else
      phone
    end
  end
end
