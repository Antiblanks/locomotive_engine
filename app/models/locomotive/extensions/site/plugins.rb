module Locomotive
  module Extensions
    module Site
      module Plugins

        extend ActiveSupport::Concern

        included do

          embeds_many :enabled_plugins, :class_name => 'Locomotive::EnabledPlugin'

          def plugins
            enabled_ids = self.enabled_plugins.inject({}) do |h, enabled_plugin|
              h[enabled_plugin.plugin_id] = true
              h
            end

            enabled_ids.default = false

            LocomotivePlugins.registered_plugins.keys.collect do |plugin_id|
              {
                :plugin_id => plugin_id,
                :plugin_name => EnabledPlugin.plugin_name(plugin_id),
                :plugin_enabled => enabled_ids[plugin_id]
              }
            end
          end

          def plugins=(plugins_hashes)
            # Convert to hashes for quick lookup
            plugin_hashes_by_id = plugins_hashes.inject({}) do |h, plugin|
              h[plugin[:plugin_id]] = plugin
              h
            end
            enabled_plugins_by_id = enabled_plugins.inject({}) do |h, enabled_plugin|
              h[enabled_plugin.plugin_id] = enabled_plugin
              h
            end

            # Enabled and disable
            LocomotivePlugins.registered_plugins.keys.each do |plugin_id|
              enabled_plugin = enabled_plugins_by_id[plugin_id]
              plugin_hash = plugin_hashes_by_id[plugin_id]
              should_enable_plugin = plugin_hash.try(:[], :enabled)

              if enabled_plugin && !should_enable_plugin
                enabled_plugin.destroy
              elsif !enabled_plugin && should_enable_plugin
                self.enabled_plugins.build(:plugin_id => plugin_id)
              end
            end

          end

        end

      end
    end
  end
end
