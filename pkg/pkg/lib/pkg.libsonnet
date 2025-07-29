local p = import 'pkg/main.libsonnet';

p.pkg({
  source: 'https://github.com/marcbran/jpoet/tree/main/pkg/pkg/lib',
  repo: 'https://github.com/marcbran/jsonnet.git',
  branch: 'pkg',
  path: 'pkg',
  target: 'p',
}, |||
  Jsonnet package definitions.
|||, {
  pkg: p.desc(|||
    Root package definition
  |||),
  desc: p.desc(|||
    Field description
  |||),
  ex: p.desc(|||
    Field example(s)
  |||),
})
