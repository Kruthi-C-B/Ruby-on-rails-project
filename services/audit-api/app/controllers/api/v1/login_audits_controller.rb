module Api
  module V1
    class LoginAuditsController < ApplicationController
      before_action :require_admin!

      def index
        audits = LoginAudit.order(created_at: :desc).limit(100)

        render json: audits.map { |audit|
          {
            id: audit.id,
            email: audit.email,
            ip_address: audit.ip_address,
            status: audit.status,
            failure_reason: audit.failure_reason,
            created_at: audit.created_at.strftime("%Y-%m-%d %H:%M:%S"),
            user_id: audit.user_id
          }
        }
      end
    end
  end
end
