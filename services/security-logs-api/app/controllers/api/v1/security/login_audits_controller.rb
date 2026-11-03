module Api
  module V1
    module Security
      class LoginAuditsController < ApplicationController
        before_action :require_localfind_admin!

        def index
          audits = LoginAudit
            .select(:id, :email, :ip_address, :status, :failure_reason, :created_at, :user_id)
            .order(created_at: :desc)
            .limit(100)

          rows = audits.map do |audit|
            {
              id: audit.id,
              email: audit.email,
              ip_address: audit.ip_address,
              status: audit.status,
              failure_reason: audit.failure_reason,
              created_at: audit.created_at.strftime("%Y-%m-%d %H:%M:%S"),
              user_id: audit.user_id
            }
          end
          render json: rows
        end
      end
    end
  end
end
