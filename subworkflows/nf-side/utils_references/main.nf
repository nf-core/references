// DISCLAIMER:
// This subworkflow is just to test the functions and the schema
// It should not be used in any pipeline

// This include statement can also be deleted
include { samplesheetToList } from 'plugin/nf-schema'

workflow UTILS_REFERENCES {
    take:
    yaml_reference
    param_file
    param_value
    attribute_file
    attribute_value
    basepath_final
    basepath_to_replace

    main:

    references = Channel.fromList(
        samplesheetToList(
            update_references_file(yaml_reference, basepath_final, basepath_to_replace),
            "${projectDir}/subworkflows/nf-side/utils_references/schema_references.json"
        )
    )

    // GIVING up writing a test for the functions, so writing a subworkflow to test it
    references_file = get_references_file(references, param_file, attribute_file)
    references_value = get_references_value(references, param_value, attribute_value)

    emit:
    references_file
    references_value
}
// You can delete everything before this line (including this line)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    FUNCTIONS TO EXTRACT REFERENCES FILES OR VALUES FROM THE REFERENCES YAML OR PARAMS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Change all igenomes base parameter values in the file to the correct value
def update_references_file(yaml_reference, basepath_final, basepath_to_replace) {
    def correct_yaml_file = file(yaml_reference, checkIfExists: true)

    if (basepath_final) {
        def staged_yaml_file = "${workflow.workDir}/tmp/${java.util.UUID.randomUUID().toString()}.${correct_yaml_file.extension}"
        correct_yaml_file.copyTo(staged_yaml_file)
        correct_yaml_file = file(staged_yaml_file, checkIfExists: true)

        // Use a local variable to accumulate changes
        def updated_yaml_content = correct_yaml_file.text
        basepath_to_replace.each { basepath_replacement ->
            updated_yaml_content = updated_yaml_content.replace(basepath_replacement, basepath_final)
        }
        correct_yaml_file.text = updated_yaml_content
    }

    return correct_yaml_file
}

def get_references_file(references, param, attribute) {
    return references
        .map { meta, _readme ->
            if (param || meta[attribute]) {
                [meta.subMap(['id']), file(param ?: meta[attribute], checkIfExists: true)]
            }
            else {
                null
            }
        }
        .collect()
}

def get_references_value(references, param, attribute) {
    return references
        .map { meta, _readme ->
            if (param || meta[attribute]) {
                [meta.subMap(['id']), param ?: meta[attribute]]
            }
            else {
                null
            }
        }
        .collect()
}
