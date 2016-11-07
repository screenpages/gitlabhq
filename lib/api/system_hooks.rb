module API
  # Hooks API
  class SystemHooks < Grape::API
    before do
      authenticate!
      authenticated_as_admin!
    end

    resource :hooks do
      desc 'Get the list of system hooks' do
        success Entities::Hook
      end
      get do
        hooks = SystemHook.all
        present hooks, with: Entities::Hook
      end

      desc 'Create a new system hook' do
        success Entities::Hook
      end
      params do
        requires :url, type: String, desc: 'The URL for the system hook'
      end
      post do
        hook = SystemHook.new declared(params).to_h

        if hook.save
          present hook, with: Entities::Hook
        else
          not_found!
        end
      end

      desc 'Test a hook'
      params do
        requires :id, type: Integer, desc: 'The ID of the system hook'
      end
      get ":id" do
        hook = SystemHook.find(params[:id])
        data = {
          event_name: "project_create",
          name: "Ruby",
          path: "ruby",
          project_id: 1,
          owner_name: "Someone",
          owner_email: "example@gitlabhq.com"
        }
        hook.execute(data, 'system_hooks')
        data
      end

      desc 'Delete a hook' do
        success Entities::Hook
      end
      params do
        requires :id, type: Integer, desc: 'The ID of the system hook'
      end
      delete ":id" do
        hook = SystemHook.find_by(id: params[:id])
        not_found!('System hook') unless hook

        present hook.destroy, with: Entities::Hook
      end
    end
  end
end
