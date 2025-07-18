local g = import 'gensonnet/main.libsonnet';

local getDeep(value, indices, default=null) =
  if std.length(indices) == 0 then value
  else
    local index = indices[0];
    if std.type(value) == 'object' && std.objectHas(value, index) then getDeep(value[index], indices[1:], default)
    else if std.type(value) == 'array' && std.type(index) == 'number' && std.length(value) > index then getDeep(value[index], indices[1:], default)
    else if std.type(value) == 'array' && std.type(index) == 'function' then getDeep([val for val in value if index(val)], indices[1:], default)
    else default;

local injectExampleString(examples, examplesNode) =
  if examples == null then null
  else if std.type(examplesNode) == 'string' then injectExampleString(examples, g.parseJsonnet(examplesNode))
  else if examplesNode.__kind__ == 'Local' then injectExampleString(examples, examplesNode.body)
  else if examplesNode.__kind__ == 'Apply' then

    local injectSingleExampleString(example, exampleNode) =
      local node = getDeep(exampleNode, ['expr', 'fields', function(field) field.id == 'example', 0, 'expr2'], null);
      example + if node != null then { string: g.manifestJsonnet(node) } else {};

    local injectArrayExampleString(examples, exampleNodes) =
      std.mapWithIndex(
        function(index, example) injectSingleExampleString(example, exampleNodes[index]),
        examples
      );

    examples {
      example: injectSingleExampleString(examples.example, getDeep(examplesNode.arguments.positional, [0], {})),
      examples: injectArrayExampleString(examples.examples, getDeep(examplesNode.arguments.positional, [0, 'expr', 'elements'], [])),
      ex: {
        children: {
          [field.id]: injectExampleString(examples.ex.children[field.id], field.expr2)
          for field in getDeep(examplesNode.arguments.positional, [1, 'expr', 'fields'], [])
        },
      },
    }
  else examplesNode;

local merge(lib, pkg, examples) =
  local mergeRec(lib, desc, examples, coordinates, usage, source) = {
    type: std.type(lib),
    implementation:: lib,
    coordinates: coordinates,
    usage: usage,
    source: source,
    description: std.get(desc, 'description', ''),
    examples: if std.type(examples) == 'object' then std.get(examples, 'examples', []) else [],
    example: if std.type(examples) == 'object' then std.get(examples, 'example', {}) else {},
    children: [
      mergeRec(
        std.get(lib, key, null),
        getDeep(desc, ['children', key], null),
        getDeep(examples, ['children', key], null),
        coordinates,
        {
          target: '%s.%s' % [usage.target, key],
          name: key,
        },
        source
      )
      for key in std.objectFields(desc.children)
    ],
  };
  mergeRec(lib, pkg, examples, pkg.coordinates, pkg.usage, pkg.source) + { root: true };

local resolvePkgConfig(lib, pkg, examples, examplesString) =
  local injectedExamples = if examples != null then injectExampleString(examples, examplesString) else {};
  local pkgConfig = merge(lib, pkg, injectedExamples);
  pkgConfig;

resolvePkgConfig
