require 'deface'

module ForemanSnapshotManagement
  class Engine < ::Rails::Engine
    engine_name 'foreman_snapshot_management'

    config.autoload_paths += Dir["#{config.root}/app/models/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/controllers/concerns"]
    config.autoload_paths += Dir["#{config.root}/app/helpers/concerns"]

    initializer 'foreman_snapshot_management.register_plugin', before: :finisher_hook do |_app|
      Foreman::Plugin.register :foreman_snapshot_management do
        requires_foreman '>= 1.17'

        apipie_documented_controllers ["#{ForemanSnapshotManagement::Engine.root}/app/controllers/api/v2/*.rb"]

        # Add permissions
        security_block :foreman_snapshot_management do
          permission :view_snapshots, {
            :'foreman_snapshot_management/snapshots' => [:index],
            :'api/v2/snapshots' => [:index, :show]
          }, :resource_type => 'Host'

          permission :create_snapshots, {
            :'foreman_snapshot_management/snapshots' => [:create],
            :'api/v2/snapshots' => [:create]
          }, :resource_type => 'Host'

          permission :edit_snapshots, {
            :'foreman_snapshot_management/snapshots' => [:update],
            :'api/v2/snapshots' => [:update]
          }, :resource_type => 'Host'

          permission :destroy_snapshots, {
            :'foreman_snapshot_management/snapshots' => [:destroy],
            :'api/v2/snapshots' => [:destroy]
          }, :resource_type => 'Host'

          permission :revert_snapshots, {
            :'foreman_snapshot_management/snapshots' => [:revert],
            :'api/v2/snapshots' => [:revert]
          }, :resource_type => 'Host'
        end

        # Adds roles if they do not exist
        role 'Snapshot Viewer', [:view_snapshots]
        role 'Snapshot Manager', [
          :view_snapshots,
          :create_snapshots,
          :edit_snapshots,
          :destroy_snapshots,
          :revert_snapshots
        ]
      end
    end

    # Precompile any JS or CSS files under app/assets/
    # If requiring files from each other, list them explicitly here to avoid precompiling the same
    # content twice.
    assets_to_precompile =
      Dir.chdir(root) do
        Dir['app/assets/javascripts/**/*', 'app/assets/stylesheets/**/*'].map do |f|
          f.split(File::SEPARATOR, 4).last
        end
      end
    initializer 'foreman_snapshot_management.assets.precompile' do |app|
      app.config.assets.precompile += assets_to_precompile
    end
    initializer 'foreman_snapshot_management.configure_assets', group: :assets do
      SETTINGS[:foreman_snapshot_management] = { assets: { precompile: assets_to_precompile } }
    end

    # Include concerns in this config.to_prepare block
    config.to_prepare do
      begin
        # Load Foreman extensions
        ::Foreman::Model::Vmware.send(:prepend, ForemanSnapshotManagement::VmwareExtensions)
        ::HostsHelper.send(:prepend, ForemanSnapshotManagement::HostsHelperExtension)

        # Load Fog extensions
        if Foreman::Model::Vmware.available?
          Fog::Compute::Vsphere::Real.send(:prepend, FogExtensions::Vsphere::Snapshots::Real)
          Fog::Compute::Vsphere::Mock.send(:prepend, FogExtensions::Vsphere::Snapshots::Mock)
        end
      rescue StandardError => e
        Rails.logger.warn "ForemanSnapshotManagement: skipping engine hook (#{e})"
      end
    end

    rake_tasks do
      Rake::Task['db:seed'].enhance do
        ForemanSnapshotManagement::Engine.load_seed
      end
    end

    initializer 'foreman_snapshot_management.register_gettext', after: :load_config_initializers do |_app|
      locale_dir = File.join(File.expand_path('../..', __dir__), 'locale')
      locale_domain = 'foreman_snapshot_management'
      Foreman::Gettext::Support.add_text_domain locale_domain, locale_dir
    end
  end
end
