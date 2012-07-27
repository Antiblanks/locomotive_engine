module Locomotive
  class EnabledPlugin

    include Locomotive::Mongoid::Document

    ## fields ##
    field :plugin_id
    field :config, :type => Hash

    ## methods ##

    def plugin_class
      LocomotivePlugins.registered_plugins[self.plugin_id]
    end

  end
end