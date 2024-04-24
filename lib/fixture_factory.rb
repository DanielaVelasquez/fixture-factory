class FixtureFactory
    class << self 
        def add_to_fixture(fixture_name, object, ignored_has_many_associations:[])
            return unless object

            attributes = fixturable_attributes(object)

            existing_data = fixture_data(object)
            existing_data[fixture_name.to_s] = attributes
    
            File.open(Rails.root.join('test', 'fixtures', fixture_file(object)), 'w') do |file|
                file.write(YAML.dump(existing_data))
            end
    
            object.class.reflections.each do |association_name, reflection|
                next if ignored_has_many_associations.include? association_name
                if reflection.macro == :has_many
                    object.send(association_name).each_with_index do |child, index|
                        next if fixture_name_for(child)
                        add_to_fixture "#{fixture_name}_#{index + 1}", child
                    end
                end
            end 
        end

        protected 

        def fixturable_attributes(object)
            attributes = object.attributes.except("id", "created_at", "updated_at")
    
            object.class.reflections.each do |association_name, reflection|
                if reflection.macro == :belongs_to
                    attributes = attributes.except(reflection.foreign_key)
                    foreign_object = object.send(association_name)
                    foreign_object_fixture_name = fixture_name_for(foreign_object)
                    # TODO: Check that the foreign object actually responds to the inverse 
                
                    attributes[association_name] = foreign_object_fixture_name ? foreign_object_fixture_name : create_fixture(foreign_object, [reflection.inverse_of&.name || object.class.name.underscore.pluralize ]) 
                end
            end
            attributes
        end
    
        def create_fixture(object, ignored_has_many_associations)
            fixture_name = object.to_s.split(" ").first.downcase
            add_to_fixture(fixture_name, object, ignored_has_many_associations:)
            fixture_name
        end
    
        def fixture_file(object)
            "#{object.class.name.underscore.pluralize}.yml"
        end
    
        def fixture_data(object)
            file_path = Rails.root.join('test', 'fixtures', fixture_file(object))
            File.exist?(file_path) ? YAML.load_file(file_path) : {}
        end
    
        def fixture_name_for(object)
            data = fixture_data(object)
            return if data.empty?
    
            attributes = fixturable_attributes(object)
    
            data.each do |fixture_key, data|
                return fixture_key if data == attributes
            end
            return nil
        end
    end

    

end