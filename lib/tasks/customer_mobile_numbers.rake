namespace :customers do
  desc "Audit mobile normalization; APPLY=1 updates only unambiguous customer numbers"
  task normalize_mobile_numbers: :environment do
    totals = { updated: 0, collisions: 0, invalid: 0 }
    Business.find_each do |business|
      counts = Customers::NormalizeMobileNumbers.call(business: business, apply: ENV["APPLY"] == "1")
      counts.each { |key, value| totals[key] += value }
    end
    puts "#{ENV['APPLY'] == '1' ? 'Applied' : 'Dry run'}: #{totals}"
  end
end
