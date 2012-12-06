module Locomotive
  class SitePresenter < BasePresenter

    delegate :name, :locales, :subdomain, :domains, :robots_txt, :seo_title, :meta_keywords, :meta_description, :domains_without_subdomain, :to => :source

    delegate :name=, :locales=, :subdomain=, :domains=, :robots_txt=, :seo_title=, :meta_keywords=, :meta_description=, :domains_without_subdomain=, :to => :source

    def domain_name
      Locomotive.config.domain
    end

    def memberships
      self.source.memberships.map { |membership| membership.as_json(self.options) }
    end

    def included_methods
      super + %w(name locales domain_name subdomain domains robots_txt seo_title meta_keywords meta_description domains_without_subdomain memberships)
    end

    def included_setters
      super + %w(name locales subdomain domains robots_txt seo_title meta_keywords meta_description domains_without_subdomain)
    end

    def as_json_for_html_view
      methods = included_methods.clone - %w(memberships)
      self.as_json(methods)
    end

    def as_json(options = nil)
      plugins = self.source.plugins do |plugin_data|
        self.ability.try(:can?, :read, plugin_data)
      end

      super.merge({
        'plugins' => plugins
      })
    end

  end
end
