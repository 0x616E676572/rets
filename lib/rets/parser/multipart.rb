module Rets
  module Parser
    # Inspired by Mail.
    class Multipart
      CRLF = "\r\n"
      WSP  = "\s"
      HEADER_LINE = /^([!-9;-~]+:\s*.+)$/

      Part = Struct.new(:headers, :body)

      def self.parse(raw, boundary)
        parts = []
        boundary_regexp = /--#{Regexp.quote(boundary)}(--)?#{CRLF}/

        # WTF some RETS servers declare response body including jpeg binary is encoded in utf8
        raw.force_encoding 'ascii-8bit' if raw.respond_to?(:force_encoding)

        raw.split(boundary_regexp).each do |chunk|
          header_part, body_part = chunk.split(/#{CRLF}#{WSP}*#{CRLF}/m, 2)

          if header_part =~ HEADER_LINE
            headers = { "ObjectData" => [] }
            header_part.split(/\r\n/).each do |kv|
              name, *contents = kv.split(/:\s?/)
              content = contents.join(":")
              name == "ObjectData" ? headers[name] << content : headers[name] = content
            end
            if headers["ObjectData"].present?
              headers["ObjectData"] = Rack::Utils.parse_nested_query(headers["ObjectData"].join("&"))
            else
              headers.delete("ObjectData")
            end

            parts << Part.new(headers, body_part)
          else
            next # not a valid chunk.
          end
        end
        check_for_invalids_parts!(parts)
        parts
      end

      def self.check_for_invalids_parts!(parts)
        return unless parts.length == 1 && parts.first.headers['content-type'] == 'text/xml'
        ErrorChecker.check(parts.first)
      end
    end
  end
end
