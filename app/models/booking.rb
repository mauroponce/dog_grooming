# Grooming terminology facade. It intentionally shares the existing
# appointments table and all Appointment behavior while avoiding an STI column.
class Booking < Appointment
  self.table_name = "appointments"
  self.inheritance_column = :_type_disabled
end
