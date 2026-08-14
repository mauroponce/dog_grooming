module LiveStreams
  module_function

  def public_services(business)
    [ :public_services, business ]
  end

  def admin_appointments(business)
    [ :admin_appointments, business ]
  end
end
