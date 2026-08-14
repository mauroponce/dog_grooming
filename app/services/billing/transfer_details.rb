module Billing
  class TransferDetails
    def self.current
      BillingTransferAccount.current
    end

    def self.alias
      current.transfer_alias
    end

    def self.account
      current.cbu
    end

    def self.holder
      current.account_holder
    end

    def self.tax_id
      current.tax_id
    end

    def self.configured?
      current.configured?
    end
  end
end
