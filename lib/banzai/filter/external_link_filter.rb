module Banzai
  module Filter
    # HTML Filter to modify the attributes of external links
    class ExternalLinkFilter < HTML::Pipeline::Filter
      def call
        doc.search('a').each do |node|
          link = node.attr('href')

          next unless link

          # Skip non-HTTP(S) links
          next unless link.start_with?('http')

          # Skip internal links
          next if link.start_with?(internal_url)

          node.set_attribute('rel', 'nofollow noreferrer')
        end

        doc
      end

      private

      def internal_url
        @internal_url ||= Gitlab.config.gitlab.url
      end
    end
  end
end
