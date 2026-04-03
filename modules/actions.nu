use ./utils.nu

# ── Action registry ────────────────────────────────────────────────────────

def action-registry [] {
    {
        "azure-pipeline": {
            name: "azure-pipeline"
            display_name: "Azure Pipeline: Create & Run"
            action_id: "azure:pipeline:create-and-run"
            file: "azurePipelineAction.ts"
            module_ref: "./extensions/azurePipelineAction"
            description: "Creates an Azure DevOps pipeline definition from a YAML file in the repo and triggers its first run. Supports setting secret pipeline variables (e.g. registry credentials)."
            inputs: "organization, project, repoName, pipelineName, agentPoolName?, pipelineYamlPath, variables?"
            outputs: "pipelineId, pipelineUrl, runId, runUrl"
            notes: "Requires integrations.azure configured in app-config. Uses Build Definitions API so secret pipeline variables can be set at creation time."
        }
    }
}

# Returns the TypeScript source for azurePipelineAction.ts
def azure-pipeline-action-source [] {
"import {
  createTemplateAction,
  scaffolderActionsExtensionPoint,
} from '@backstage/plugin-scaffolder-node';
import {
  ScmIntegrations,
  DefaultAzureDevOpsCredentialsProvider,
} from '@backstage/integration';
import {
  coreServices,
  createBackendModule,
} from '@backstage/backend-plugin-api';

function createAzurePipelineAction(integrations: ScmIntegrations) {
  const credentialsProvider =
    DefaultAzureDevOpsCredentialsProvider.fromIntegrations(integrations);

  return createTemplateAction({
    id: 'azure:pipeline:create-and-run',
    description:
      'Creates an Azure DevOps pipeline from a YAML file in the repo and triggers its first run',
    schema: {
      input: {
        organization: (z: any) => z.string().describe('Azure DevOps Organization name'),
        project: (z: any) => z.string().describe('Azure DevOps Project name'),
        repoName: (z: any) => z.string().describe('Repository name'),
        pipelineName: (z: any) => z.string().describe('Name to give the pipeline'),
        agentPoolName: (z: any) =>
          z
            .string()
            .optional()
            .describe('Default agent pool name for the pipeline definition'),
        pipelineYamlPath: (z: any) =>
          z
            .string()
            .default('azure-pipelines.yml')
            .describe('Path to the pipeline YAML file inside the repo (no leading slash)'),
        variables: (z: any) =>
          z
            .record(
              z.object({
                value: z.string(),
                isSecret: z.boolean().optional(),
              }),
            )
            .optional()
            .describe('Pipeline variables to set (use isSecret: true for secrets)'),
      },
      output: {
        pipelineId: (z: any) => z.number().describe('Created pipeline ID'),
        pipelineUrl: (z: any) => z.string().describe('Pipeline web URL'),
        runId: (z: any) => z.number().describe('Triggered run ID'),
        runUrl: (z: any) => z.string().describe('Run web URL'),
      },
    },

    async handler(ctx) {
      const {
        organization,
        project,
        repoName,
        pipelineName,
        agentPoolName,
        pipelineYamlPath,
        variables,
      } = ctx.input as {
        organization: string;
        project: string;
        repoName: string;
        pipelineName: string;
        agentPoolName?: string;
        pipelineYamlPath: string;
        variables?: Record<string, { value: string; isSecret?: boolean }>;
      };

      const orgUrl = `https://dev.azure.com/${organization}`;

      const credentials = await credentialsProvider.getCredentials({
        url: `${orgUrl}/${project}`,
      });
      if (!credentials) {
        throw new Error(
          `No Azure DevOps credentials found for ${orgUrl}. ` +
            'Ensure integrations.azure is configured with a PAT token in app-config.',
        );
      }

      const authHeader =
        credentials.type === 'pat'
          ? `Basic ${Buffer.from(`:${credentials.token}`).toString('base64')}`
          : `Bearer ${credentials.token}`;

      const apiBase = `${orgUrl}/${project}/_apis`;

      // 1. Resolve the repository ID
      ctx.logger.info(`Looking up repository \"${repoName}\" in project \"${project}\"...`);
      const reposRes = await fetch(
        `${apiBase}/git/repositories?api-version=7.0`,
        { headers: { Authorization: authHeader } },
      );
      if (!reposRes.ok) {
        throw new Error(
          `Failed to list repositories: ${reposRes.status} ${await reposRes.text()}`,
        );
      }
      const reposBody = (await reposRes.json()) as {
        value: { id: string; name: string }[];
      };
      const repo = reposBody.value.find(r => r.name === repoName);
      if (!repo) {
        throw new Error(
          `Repository \"${repoName}\" not found in project \"${project}\". ` +
            `Available: ${reposBody.value.map(r => r.name).join(', ')}`,
        );
      }

      // 2. Create the pipeline definition via Build Definitions API (supports variables)
      ctx.logger.info(`Creating pipeline \"${pipelineName}\"...`);

      const varPayload: Record<
        string,
        { value: string; isSecret: boolean; allowOverride: boolean }
      > = {};
      if (variables) {
        for (const [key, v] of Object.entries(variables)) {
          varPayload[key] = {
            value: v.value,
            isSecret: v.isSecret ?? false,
            allowOverride: false,
          };
        }
      }

      const createBody: Record<string, unknown> = {
        name: pipelineName,
        process: { type: 2, yamlFilename: pipelineYamlPath.replace(/^\\/+/, '') },
        repository: { id: repo.id, type: 'TfsGit', name: repoName },
        ...(agentPoolName ? { queue: { name: agentPoolName } } : {}),
      };
      if (Object.keys(varPayload).length > 0) {
        createBody.variables = varPayload;
      }

      const createRes = await fetch(
        `${apiBase}/build/definitions?api-version=7.0`,
        {
          method: 'POST',
          headers: {
            Authorization: authHeader,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(createBody),
        },
      );
      if (!createRes.ok) {
        throw new Error(
          `Failed to create pipeline: ${createRes.status} ${await createRes.text()}`,
        );
      }
      const pipeline = (await createRes.json()) as {
        id: number;
        _links: { web: { href: string } };
      };
      ctx.logger.info(`Pipeline created — ID: ${pipeline.id}`);

      // 3. Trigger the first run via Build Queuing API (more reliable with self-hosted pools)
      ctx.logger.info('Triggering pipeline run...');
      const runRes = await fetch(
        `${apiBase}/build/builds?api-version=7.0`,
        {
          method: 'POST',
          headers: {
            Authorization: authHeader,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            definition: { id: pipeline.id },
            sourceBranch: 'refs/heads/main',
          }),
        },
      );
      if (!runRes.ok) {
        throw new Error(
          `Pipeline created (ID: ${pipeline.id}) but failed to trigger run: ` +
            `${runRes.status} ${await runRes.text()}`,
        );
      }
      const run = (await runRes.json()) as {
        id: number;
        _links: { web: { href: string } };
      };
      ctx.logger.info(`Pipeline run triggered — Run ID: ${run.id}`);

      ctx.output('pipelineId', pipeline.id);
      ctx.output('pipelineUrl', pipeline._links.web.href);
      ctx.output('runId', run.id);
      ctx.output('runUrl', run._links.web.href);
    },
  });
}

export const scaffolderModuleAzurePipeline = createBackendModule({
  pluginId: 'scaffolder',
  moduleId: 'azure-pipeline',
  register(reg) {
    reg.registerInit({
      deps: {
        scaffolderActions: scaffolderActionsExtensionPoint,
        rootConfig: coreServices.rootConfig,
      },
      async init({ scaffolderActions, rootConfig }) {
        const integrations = ScmIntegrations.fromConfig(rootConfig);
        scaffolderActions.addActions(createAzurePipelineAction(integrations));
      },
    });
  },
});

// Default export required by backend.add(import('./extensions/azurePipelineAction'))
export default scaffolderModuleAzurePipeline;
"
}

# Patch packages/backend/src/index.ts to register the action module.
# Idempotent: no-op if the import is already present.
def patch-index-with-action [instance_path: string, action: record] {
    let index_path = ($instance_path + "/packages/backend/src/index.ts")
    if not ($index_path | path exists) {
        utils print-warning "packages/backend/src/index.ts not found — skipping index patch"
        return
    }

    let content = (open --raw $index_path)
    let module_ref = $action.module_ref

    if ($content | str contains $module_ref) {
        utils print-info $"index.ts already registers ($module_ref)"
        return
    }

    $content | save --force ($index_path + ".bak")

    let new_line = $"backend.add\(import\('($module_ref)'\)\);"
    let new_content = $content | str replace "backend.start();" ($new_line + "\n\nbackend.start();")
    $new_content | save --force $index_path
    utils print-success $"packages/backend/src/index.ts patched with ($module_ref)"
}

# ── Public exports ─────────────────────────────────────────────────────────

# List all available custom scaffolder actions
export def list-available-actions [] {
    let colors = ({
        cyan:  (ansi cyan)
        bold:  (ansi attr_bold)
        reset: (ansi reset)
        green: (ansi green)
        dim:   (ansi dark_gray)
    })

    utils print-header "Available Custom Scaffolder Actions"

    let registry = (action-registry)
    $registry | items {|name, action|
        print $"  ($colors.cyan)($colors.bold)($name)($colors.reset)  —  ($action.action_id)"
        print $"  ($colors.dim)($action.description)($colors.reset)"
        print ""
    }
}

# Show detailed information about a custom scaffolder action
export def show-action-info [name: string] {
    let registry = (action-registry)

    if not ($registry | columns | any {|k| $k == $name}) {
        utils print-error $"Unknown action: ($name). Run 'platform action list' to see available actions."
        exit 1
    }

    let action = ($registry | get $name)
    let colors = ({
        cyan:  (ansi cyan)
        bold:  (ansi attr_bold)
        reset: (ansi reset)
        green: (ansi green)
        yellow: (ansi yellow)
        dim:   (ansi dark_gray)
    })

    utils print-header $"Action: ($action.display_name)"
    print $"  ($colors.bold)Action ID:($colors.reset)    ($colors.cyan)($action.action_id)($colors.reset)"
    print $"  ($colors.bold)File:($colors.reset)         ($action.file)"
    print $"  ($colors.bold)Description:($colors.reset)  ($action.description)"
    print ""
    print $"  ($colors.bold)Inputs:($colors.reset)   ($action.inputs)"
    print $"  ($colors.bold)Outputs:($colors.reset)  ($action.outputs)"
    print ""
    print $"  ($colors.bold)Notes:($colors.reset)"
    print $"    ($action.notes)"
    print ""
    print $"  ($colors.bold)Usage in template.yaml:($colors.reset)"
    print $"    - id: create-pipeline"
    print $"      action: ($action.action_id)"
    print $"      input:"
    print $"        organization: \$\{{ parameters.ado_organization \}}"
    print $"        project: \$\{{ parameters.ado_project \}}"
    print $"        repoName: \$\{{ parameters.component_id \}}"
    print $"        pipelineName: \$\{{ parameters.component_id \}}-cicd"
}

# Install a custom scaffolder action into a Backstage instance
export def install-action [
    name: string          # Action name (e.g. azure-pipeline)
    instance_path: string # Path to the Backstage instance root
] {
    let registry = (action-registry)

    if not ($registry | columns | any {|k| $k == $name}) {
        utils print-error $"Unknown action: ($name). Run 'platform action list' to see available actions."
        exit 1
    }

    let abs_path = ($instance_path | path expand)
    if not ($abs_path | path exists) {
        utils print-error $"Instance path not found: ($abs_path)"
        exit 1
    }

    let backend_src = ($abs_path + "/packages/backend/src")
    if not ($backend_src | path exists) {
        utils print-error $"Not a valid Backstage instance: missing packages/backend/src in ($abs_path)"
        exit 1
    }

    let action = ($registry | get $name)

    utils print-header $"Installing Action: ($action.display_name)"

    # 1. Ensure extensions directory exists
    let ext_dir = ($abs_path + "/packages/backend/src/extensions")
    if not ($ext_dir | path exists) {
        mkdir $ext_dir
        utils print-success "Created packages/backend/src/extensions/"
    }

    # 2. Write the TypeScript source file (idempotent check)
    let ts_path = ($ext_dir + "/" + $action.file)
    if ($ts_path | path exists) {
        utils print-info $"($action.file) already exists — overwriting with latest version"
    }

    let source = (match $name {
        "azure-pipeline" => (azure-pipeline-action-source)
        _ => { utils print-error $"No source defined for action: ($name)"; exit 1 }
    })
    $source | save --force $ts_path
    utils print-success $"Created packages/backend/src/extensions/($action.file)"

    # 3. Patch index.ts
    patch-index-with-action $abs_path $action

    utils print-success $"Action ($action.action_id) is ready"
    utils print-info $"  Restart the Backstage backend to load the new action."
    utils print-info $"  Verify: curl http://localhost:7007/api/scaffolder/v2/actions | grep '($action.action_id)'"
}
