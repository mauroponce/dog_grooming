class CreateServiceCatalog < ActiveRecord::Migration[8.1]
  CATALOG = [
    {
      key: "general",
      name: "Centro de estética general",
      description: "Centro integral con servicios faciales, corporales, depilación, uñas y mirada.",
      business_industry: "aesthetics",
      items: [
        [ "Evaluación estética inicial", "General", "Primera evaluación para recomendar protocolos y armar un plan de tratamiento.", 30, 0, 0 ],
        [ "Limpieza facial profunda", "Facial", "Higiene facial con extracciones, alta frecuencia e hidratación según tipo de piel.", 90, 40_000, 10_000 ],
        [ "Hidrofacial", "Facial", "Limpieza, exfoliación e infusión de sueros mediante succión profunda.", 60, 55_000, 12_000 ],
        [ "Drenaje linfático manual", "Corporal", "Masaje suave para estimular el sistema linfático y aliviar retención de líquidos.", 60, 36_000, 8_000 ],
        [ "Depilación láser axilas", "Depilación", "Sesión láser por zona con indicaciones previas y posteriores.", 30, 18_000, 4_000 ],
        [ "Diseño y perfilado de cejas", "Cejas y pestañas", "Diseño de cejas personalizado según la morfología del rostro.", 30, 15_000, 3_000 ],
        [ "Esmaltado semipermanente", "Uñas", "Esmaltado en cabina LED/UV de alta duración.", 60, 22_000, 5_000 ],
        [ "Toxina botulínica", "Medicina estética", "Aplicación médica para suavizar arrugas dinámicas. Requiere profesional habilitado.", 30, 0, 0 ]
      ]
    },
    {
      key: "facial",
      name: "Tratamientos Faciales",
      description: "Cuidado, rejuvenecimiento y corrección de la piel del rostro.",
      business_industry: "aesthetics",
      items: [
        [ "Limpieza facial profunda / Higiene cutánea", "Facial", "Extracción de comedones, vaporozono y alta frecuencia para desinfectar.", 90, 40_000, 10_000 ],
        [ "Hidrofacial / Hydrafacial", "Facial", "Limpieza, exfoliación e infusión de sueros mediante succión profunda.", 60, 55_000, 12_000 ],
        [ "Peeling químico suave", "Facial", "Aplicación de ácidos superficiales para renovar textura, luminosidad y manchas leves.", 45, 36_000, 8_000 ],
        [ "Microdermoabrasión punta de diamante", "Facial", "Exfoliación mecánica para eliminar células muertas y pulir la piel.", 45, 34_000, 7_000 ],
        [ "Radiofrecuencia facial", "Facial", "Ondas electromagnéticas que generan calor interno para estimular colágeno y firmeza.", 60, 42_000, 9_000 ],
        [ "Microneedling Dermapen", "Facial", "Microperforaciones controladas para estimular renovación y absorción de activos.", 60, 55_000, 12_000 ],
        [ "HIFU facial", "Aparatología", "Ultrasonido focalizado para trabajar firmeza facial sin cirugía.", 60, 95_000, 20_000 ],
        [ "Masaje facial Kobido", "Facial", "Masaje facial japonés de efecto tensor y drenante.", 60, 38_000, 8_000 ]
      ]
    },
    {
      key: "corporal",
      name: "Tratamientos Corporales",
      description: "Reducción, celulitis, flacidez, drenaje y bienestar corporal.",
      business_industry: "aesthetics",
      items: [
        [ "Cavitación", "Aparatología", "Ultrasonido de baja frecuencia para acompañar protocolos reductores.", 45, 38_000, 8_000 ],
        [ "Lipoláser", "Aparatología", "Tratamiento corporal localizado con lipoláser y protocolo complementario.", 45, 38_000, 8_000 ],
        [ "Criolipólisis", "Aparatología", "Aplicación de frío controlado para tratamiento localizado de adiposidad.", 60, 54_000, 12_000 ],
        [ "Presoterapia", "Corporal", "Compresión neumática para drenaje, piernas cansadas y retención de líquidos.", 45, 28_000, 6_000 ],
        [ "Ondas de choque", "Aparatología", "Impulsos acústicos para protocolos de celulitis y calidad de piel.", 45, 42_000, 9_000 ],
        [ "Electromusculación / EMSCULPT", "Aparatología", "Contracciones electromagnéticas para tonificación muscular.", 30, 45_000, 10_000 ],
        [ "Drenaje linfático manual", "Corporal", "Masaje suave para estimular el sistema linfático y acompañar postoperatorios.", 60, 36_000, 8_000 ],
        [ "Maderoterapia", "Corporal", "Masaje con utensilios de madera para moldear, relajar y acompañar protocolos corporales.", 60, 36_000, 8_000 ],
        [ "Masaje relajante / descontracturante", "Masajes", "Masaje corporal orientado a relajación general o zonas tensionadas.", 60, 36_000, 0 ],
        [ "Exfoliación corporal y envolturas", "Spa", "Tratamiento con exfoliación y envolturas nutritivas o descongestivas.", 60, 38_000, 8_000 ]
      ]
    },
    {
      key: "depilacion",
      name: "Depilación",
      description: "Depilación láser, IPL y métodos tradicionales.",
      business_industry: "aesthetics",
      items: [
        [ "Depilación láser", "Depilación", "Eliminación progresiva del vello por fototermólisis selectiva.", 30, 18_000, 4_000 ],
        [ "Luz pulsada intensa IPL", "Depilación", "Sesión con luz pulsada para depilación o fototratamiento según protocolo.", 45, 34_000, 7_000 ],
        [ "Depilación tradicional con cera", "Depilación", "Depilación tradicional por zonas con sistema español o descartable.", 45, 22_000, 5_000 ],
        [ "Depilación con hilo rostro", "Depilación", "Depilación facial con hilo, ideal para cejas, bozo o rostro.", 30, 16_000, 3_000 ]
      ]
    },
    {
      key: "cejas_pestanas",
      name: "Cejas y Pestañas",
      description: "Servicios para mirada, cejas y pestañas.",
      business_industry: "aesthetics",
      items: [
        [ "Lifting de pestañas", "Cejas y pestañas", "Elevación de pestañas naturales desde la raíz con efecto abierto.", 60, 26_000, 6_000 ],
        [ "Extensiones de pestañas clásicas", "Cejas y pestañas", "Aplicación pelo por pelo con efecto natural.", 120, 48_000, 10_000 ],
        [ "Extensiones de pestañas volumen ruso", "Cejas y pestañas", "Aplicación de volumen para un resultado más intenso.", 120, 58_000, 12_000 ],
        [ "Laminado de cejas", "Cejas y pestañas", "Peinado y fijación semipermanente para ordenar cejas rebeldes.", 45, 22_000, 5_000 ],
        [ "Diseño y perfilado de cejas", "Cejas y pestañas", "Esculpido personalizado según la morfología del rostro.", 30, 15_000, 3_000 ]
      ]
    },
    {
      key: "nails",
      name: "Nails / Manicuría",
      description: "Uñas esculpidas, gel, nail art y esmaltado moderno.",
      business_industry: "nails",
      items: [
        [ "Esmaltado semipermanente", "Uñas", "Esmaltado en cabina LED/UV de alta duración.", 60, 22_000, 5_000 ],
        [ "Kapping gel", "Uñas", "Refuerzo de uña natural con gel y esmaltado.", 90, 34_000, 8_000 ],
        [ "Uñas esculpidas en gel", "Uñas", "Extensión y construcción de uñas en gel con terminación personalizada.", 120, 48_000, 10_000 ],
        [ "Uñas acrílicas", "Uñas", "Esculpido acrílico para largo y forma personalizados.", 120, 48_000, 10_000 ],
        [ "Polygel", "Uñas", "Extensión o refuerzo con polygel para estructura resistente.", 120, 50_000, 10_000 ],
        [ "Soft gel", "Uñas", "Extensión con tips soft gel y esmaltado.", 90, 42_000, 9_000 ],
        [ "Nail art simple", "Uñas", "Diseño simple, detalles o decoración por uña.", 30, 8_000, 0 ],
        [ "Retiro de esmaltado o gel", "Uñas", "Retiro cuidado de producto anterior y preparación de la uña.", 30, 10_000, 0 ]
      ]
    },
    {
      key: "manicuria_pedicuria",
      name: "Manicuría y Pedicuría",
      description: "Manos y pies: esmaltado, cutículas, spa y parafina.",
      business_industry: "nails",
      items: [
        [ "Manicuría tradicional", "Uñas", "Limpieza de cutículas, limado y esmaltado clásico.", 45, 16_000, 3_000 ],
        [ "Manicuría combinada", "Uñas", "Técnica combinada para cutícula prolija y esmaltado de alta duración.", 75, 25_000, 5_000 ],
        [ "Pedicuría estética", "Uñas", "Cuidado estético de pies, limado, cutículas e hidratación.", 60, 24_000, 5_000 ],
        [ "Pedicuría spa", "Uñas", "Pedicuría estética con exfoliación, hidratación y masaje breve.", 75, 30_000, 6_000 ],
        [ "Esmaltado semipermanente", "Uñas", "Esmaltado en cabina LED/UV de alta duración.", 60, 22_000, 5_000 ],
        [ "Tratamiento de parafina manos", "Uñas", "Hidratación intensiva para manos secas con baño de parafina.", 30, 12_000, 0 ],
        [ "Tratamiento de parafina pies", "Uñas", "Hidratación intensiva para pies secos con baño de parafina.", 30, 14_000, 0 ]
      ]
    },
    {
      key: "medicina_estetica",
      name: "Medicina Estética",
      description: "Tratamientos médicos mínimamente invasivos realizados por profesional habilitado.",
      business_industry: "aesthetics",
      items: [
        [ "Toxina botulínica", "Medicina estética", "Aplicación médica para suavizar arrugas dinámicas o tratar bruxismo.", 30, 0, 0 ],
        [ "Rellenos dérmicos con ácido hialurónico", "Medicina estética", "Voluminización y armonización de labios, pómulos, mentón, ojeras o surcos.", 45, 0, 0 ],
        [ "Bioestimuladores de colágeno", "Medicina estética", "Inyectables que estimulan la generación de colágeno y firmeza.", 60, 0, 0 ],
        [ "Mesoterapia facial y corporal", "Medicina estética", "Microinyecciones de vitaminas, aminoácidos o activos según evaluación médica.", 45, 0, 0 ],
        [ "Carboxiterapia", "Medicina estética", "Aplicación subcutánea de CO2 para mejorar microcirculación, celulitis o flacidez.", 45, 0, 0 ],
        [ "Plasma rico en plaquetas PRP", "Medicina estética", "Tratamiento regenerativo con factores de crecimiento realizado por profesional habilitado.", 60, 0, 0 ],
        [ "Exosomas", "Medicina estética", "Terapia regenerativa avanzada según evaluación profesional.", 60, 0, 0 ]
      ]
    }
  ].freeze

  def up
    create_table :service_catalog_categories do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.text :description
      t.string :business_industry, null: false, default: "aesthetics"
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :service_catalog_categories, :key, unique: true
    add_index :service_catalog_categories, [ :active, :sort_order ], name: "idx_service_catalog_categories_active_order"

    create_table :service_catalog_items do |t|
      t.references :service_catalog_category, null: false, foreign_key: true
      t.string :name, null: false
      t.string :service_category, null: false
      t.text :description, null: false
      t.integer :duration_minutes, null: false
      t.integer :price_cents, null: false, default: 0
      t.integer :deposit_amount_cents, null: false, default: 0
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :service_catalog_items, [ :service_catalog_category_id, :name ], unique: true, name: "idx_service_catalog_items_category_name"
    add_index :service_catalog_items, [ :service_catalog_category_id, :active, :sort_order ], name: "idx_service_catalog_items_category_active_order"

    add_reference :businesses, :service_catalog_category, foreign_key: true

    seed_catalog!
  end

  def down
    remove_reference :businesses, :service_catalog_category, foreign_key: true
    drop_table :service_catalog_items
    drop_table :service_catalog_categories
  end

  private
    def seed_catalog!
      category_model = Class.new(ActiveRecord::Base) do
        self.table_name = "service_catalog_categories"
      end
      item_model = Class.new(ActiveRecord::Base) do
        self.table_name = "service_catalog_items"
      end
      business_model = Class.new(ActiveRecord::Base) do
        self.table_name = "businesses"
      end

      CATALOG.each_with_index do |category, category_index|
        category_record = category_model.create!(
          key: category.fetch(:key),
          name: category.fetch(:name),
          description: category.fetch(:description),
          business_industry: category.fetch(:business_industry),
          sort_order: category_index
        )

        category.fetch(:items).each_with_index do |item, item_index|
          name, service_category, description, duration_minutes, price, deposit = item
          item_model.create!(
            service_catalog_category_id: category_record.id,
            name: name,
            service_category: service_category,
            description: description,
            duration_minutes: duration_minutes,
            price_cents: cents(price),
            deposit_amount_cents: cents(deposit),
            sort_order: item_index
          )
        end
      end

      default_category = category_model.find_by!(key: "general")
      business_model.where(service_catalog_category_id: nil).update_all(service_catalog_category_id: default_category.id)
    end

    def cents(amount)
      amount.to_i * 100
    end
end
