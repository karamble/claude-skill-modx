<?php
/**
 * MODX Revolution 3.x CLI bridge
 *
 * A minimal PHP CLI entry point that bootstraps MODX in API mode and dispatches
 * JSON commands over stdin. Designed to run under a PHP user via runuser, behind
 * an Apache deny-all rule, invoked over SSH from a developer workstation.
 *
 * Usage (from an SSH session on the server):
 *     runuser -u <php_user> -- php <web_root>/cli/modx-cli.php <<< '{"action":"ping"}'
 *
 * Or from an external shell with SSH:
 *     ssh <ssh_user>@<host> "runuser -u <php_user> -- php <web_root>/cli/modx-cli.php" <<< '{"action":"ping"}'
 *
 * Commands are JSON objects on stdin. Responses are JSON on stdout.
 * Errors go to stderr with a non-zero exit code.
 *
 * Security:
 *   - PHP_SAPI check kills the file instantly if hit over HTTP.
 *   - The /cli/ directory has an .htaccess Deny from all rule.
 *   - File should be mode 0640 owned by the PHP user.
 *   - Anyone with the configured ssh_user access has equal or greater power anyway;
 *     this script exists to give that access a clean, idiomatic API surface,
 *     not to add privilege.
 *
 * Part of: github.com/karamble/claude-skill-modx
 * Bridge version: 0.1.0
 */

// ---------------------------------------------------------------------------
// Hard guard: this file must NEVER run via a web request.
// ---------------------------------------------------------------------------
if (PHP_SAPI !== 'cli') {
    http_response_code(403);
    exit('CLI only');
}

// ---------------------------------------------------------------------------
// Bootstrap MODX in API mode via the front controller.
// ---------------------------------------------------------------------------
define('MODX_API_MODE', true);
require dirname(__DIR__) . '/index.php';

/** @var MODX\Revolution\modX $modx */
if (!isset($modx) || !$modx instanceof \MODX\Revolution\modX) {
    fwrite(STDERR, "Error: MODX failed to bootstrap\n");
    exit(2);
}

$modx->getService('error', 'error.modError');
$modx->setLogLevel(\MODX\Revolution\modX::LOG_LEVEL_ERROR);
$modx->setLogTarget('ECHO');

// ---------------------------------------------------------------------------
// Read command from stdin.
// ---------------------------------------------------------------------------
$input = stream_get_contents(STDIN);
if ($input === false || trim($input) === '') {
    fwrite(STDERR, "Error: no JSON command received on stdin\n");
    fwrite(STDERR, "Usage: echo '{\"action\":\"ping\"}' | php modx-cli.php\n");
    exit(1);
}

$cmd = json_decode($input, true);
if (!is_array($cmd) || !isset($cmd['action'])) {
    fwrite(STDERR, "Error: invalid JSON or missing 'action': " . json_last_error_msg() . "\n");
    exit(1);
}

// ---------------------------------------------------------------------------
// Dispatcher
// ---------------------------------------------------------------------------
$action = $cmd['action'];

try {
    $result = dispatch($modx, $action, $cmd);
} catch (\Throwable $e) {
    $result = ['error' => $e->getMessage(), 'type' => get_class($e), 'file' => $e->getFile(), 'line' => $e->getLine()];
    fwrite(STDOUT, json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");
    exit(3);
}

echo json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n";
exit(0);

// ===========================================================================
// Dispatcher and actions
// ===========================================================================

function dispatch(\MODX\Revolution\modX $modx, string $action, array $cmd)
{
    switch ($action) {

        // ---------- SYSTEM -------------------------------------------------
        case 'ping':
            return [
                'ok'             => true,
                'bridge_version' => '0.1.0',
                'modx'           => $modx->version['full_version'] ?? 'unknown',
                'site_name'      => $modx->getOption('site_name'),
                'base_path'      => MODX_BASE_PATH,
                'core_path'      => MODX_CORE_PATH,
                'php'            => PHP_VERSION,
                'user'           => function_exists('posix_getpwuid') ? (posix_getpwuid(posix_geteuid())['name'] ?? 'unknown') : 'unknown',
            ];

        case 'cache_clear':
            $modx->cacheManager->refresh();
            return ['ok' => true, 'cache' => 'refreshed'];

        // ---------- RESOURCES ----------------------------------------------
        case 'resource_list':
            $q = $modx->newQuery(\MODX\Revolution\modResource::class);
            if (isset($cmd['parent']))   $q->where(['parent' => (int) $cmd['parent']]);
            if (isset($cmd['template'])) {
                $tpl = resolveTemplate($modx, $cmd['template']);
                if ($tpl) $q->where(['template' => $tpl->get('id')]);
            }
            if (isset($cmd['published'])) $q->where(['published' => (bool) $cmd['published']]);
            $q->sortby('menuindex', 'ASC');
            $out = [];
            foreach ($modx->getIterator(\MODX\Revolution\modResource::class, $q) as $r) {
                $out[] = briefResource($modx, $r);
            }
            return $out;

        case 'resource_get':
            $r = loadResource($modx, $cmd);
            if (!$r) return ['error' => 'resource not found'];
            return fullResource($modx, $r, !empty($cmd['include_content']));

        case 'resource_create':
            $r = $modx->newObject(\MODX\Revolution\modResource::class);
            applyResourceFields($modx, $r, $cmd['fields'] ?? []);
            if (!$r->save()) return ['error' => 'save failed'];
            if (!empty($cmd['tvs'])) setResourceTvs($modx, $r, $cmd['tvs']);
            return ['ok' => true, 'id' => $r->get('id'), 'alias' => $r->get('alias')];

        case 'resource_update':
            $r = loadResource($modx, $cmd);
            if (!$r) return ['error' => 'resource not found'];
            if (!empty($cmd['fields'])) applyResourceFields($modx, $r, $cmd['fields']);
            if (!$r->save()) return ['error' => 'save failed'];
            if (!empty($cmd['tvs'])) setResourceTvs($modx, $r, $cmd['tvs']);
            return ['ok' => true, 'id' => $r->get('id'), 'alias' => $r->get('alias')];

        case 'resource_delete':
            $r = loadResource($modx, $cmd);
            if (!$r) return ['error' => 'resource not found'];
            $id = $r->get('id');
            $hard = !empty($cmd['hard']);
            if ($hard) {
                if (!$r->remove()) return ['error' => 'remove failed'];
            } else {
                $r->set('deleted', true);
                $r->save();
            }
            return ['ok' => true, 'id' => $id, 'hard' => $hard];

        // ---------- CHUNKS -------------------------------------------------
        case 'chunk_list':
            return listElements($modx, \MODX\Revolution\modChunk::class, 'name');

        case 'chunk_get':
            $c = $modx->getObject(\MODX\Revolution\modChunk::class, ['name' => $cmd['name']]);
            if (!$c) return ['error' => 'chunk not found'];
            return chunkToArray($modx, $c);

        case 'chunk_create':
        case 'chunk_update':
            $c = $modx->getObject(\MODX\Revolution\modChunk::class, ['name' => $cmd['name']]);
            if (!$c) {
                $c = $modx->newObject(\MODX\Revolution\modChunk::class);
                $c->set('name', $cmd['name']);
                $created = true;
            } else {
                $created = false;
            }
            if (isset($cmd['content']))     $c->set('snippet', $cmd['content']);
            if (isset($cmd['description'])) $c->set('description', $cmd['description']);
            if (isset($cmd['category']))    $c->set('category', resolveCategoryId($modx, $cmd['category']));
            if (!$c->save()) return ['error' => 'save failed'];
            return ['ok' => true, 'name' => $c->get('name'), 'id' => $c->get('id'), 'created' => $created];

        case 'chunk_delete':
            $c = $modx->getObject(\MODX\Revolution\modChunk::class, ['name' => $cmd['name']]);
            if (!$c) return ['error' => 'chunk not found'];
            $c->remove();
            return ['ok' => true, 'name' => $cmd['name']];

        // ---------- TEMPLATES ----------------------------------------------
        case 'template_list':
            $out = [];
            foreach ($modx->getIterator(\MODX\Revolution\modTemplate::class) as $t) {
                $out[] = [
                    'id'           => $t->get('id'),
                    'templatename' => $t->get('templatename'),
                    'description'  => $t->get('description'),
                    'category'     => $t->get('category'),
                ];
            }
            return $out;

        case 'template_get':
            $t = resolveTemplate($modx, $cmd['name']);
            if (!$t) return ['error' => 'template not found'];
            return [
                'id'           => $t->get('id'),
                'templatename' => $t->get('templatename'),
                'description'  => $t->get('description'),
                'category'     => $t->get('category'),
                'content'      => $t->get('content'),
            ];

        case 'template_create':
        case 'template_update':
            $t = resolveTemplate($modx, $cmd['name']);
            if (!$t) {
                $t = $modx->newObject(\MODX\Revolution\modTemplate::class);
                $t->set('templatename', $cmd['name']);
                $created = true;
            } else {
                $created = false;
            }
            if (isset($cmd['content']))     $t->set('content', $cmd['content']);
            if (isset($cmd['description'])) $t->set('description', $cmd['description']);
            if (isset($cmd['category']))    $t->set('category', resolveCategoryId($modx, $cmd['category']));
            if (!$t->save()) return ['error' => 'save failed'];
            return ['ok' => true, 'templatename' => $t->get('templatename'), 'id' => $t->get('id'), 'created' => $created];

        case 'template_delete':
            $t = resolveTemplate($modx, $cmd['name']);
            if (!$t) return ['error' => 'template not found'];
            $t->remove();
            return ['ok' => true, 'name' => $cmd['name']];

        // ---------- TVs ----------------------------------------------------
        case 'tv_list':
            $out = [];
            foreach ($modx->getIterator(\MODX\Revolution\modTemplateVar::class) as $tv) {
                $out[] = [
                    'id'      => $tv->get('id'),
                    'name'    => $tv->get('name'),
                    'caption' => $tv->get('caption'),
                    'type'    => $tv->get('type'),
                ];
            }
            return $out;

        case 'tv_get':
            $tv = $modx->getObject(\MODX\Revolution\modTemplateVar::class, ['name' => $cmd['name']]);
            if (!$tv) return ['error' => 'tv not found'];
            $links = $modx->getCollection(\MODX\Revolution\modTemplateVarTemplate::class, ['tmplvarid' => $tv->get('id')]);
            $templates = [];
            foreach ($links as $link) {
                $t = $modx->getObject(\MODX\Revolution\modTemplate::class, $link->get('templateid'));
                if ($t) $templates[] = $t->get('templatename');
            }
            return [
                'id'          => $tv->get('id'),
                'name'        => $tv->get('name'),
                'caption'     => $tv->get('caption'),
                'description' => $tv->get('description'),
                'type'        => $tv->get('type'),
                'default'     => $tv->get('default_text'),
                'elements'    => $tv->get('elements'),
                'display'     => $tv->get('display'),
                'category'    => $tv->get('category'),
                'templates'   => $templates,
            ];

        case 'tv_create':
        case 'tv_update':
            $tv = $modx->getObject(\MODX\Revolution\modTemplateVar::class, ['name' => $cmd['name']]);
            if (!$tv) {
                $tv = $modx->newObject(\MODX\Revolution\modTemplateVar::class);
                $tv->set('name', $cmd['name']);
                $created = true;
            } else {
                $created = false;
            }
            if (isset($cmd['caption']))      $tv->set('caption', $cmd['caption']);
            if (isset($cmd['description']))  $tv->set('description', $cmd['description']);
            if (isset($cmd['type']))         $tv->set('type', $cmd['type']);
            if (isset($cmd['default']))      $tv->set('default_text', $cmd['default']);
            if (isset($cmd['elements']))     $tv->set('elements', $cmd['elements']);
            if (isset($cmd['display']))      $tv->set('display', $cmd['display']);
            if (isset($cmd['category']))     $tv->set('category', resolveCategoryId($modx, $cmd['category']));
            if (!$tv->save()) return ['error' => 'save failed'];
            return ['ok' => true, 'name' => $tv->get('name'), 'id' => $tv->get('id'), 'created' => $created];

        case 'tv_assign_template':
            $tv = $modx->getObject(\MODX\Revolution\modTemplateVar::class, ['name' => $cmd['tv']]);
            if (!$tv) return ['error' => 'tv not found'];
            $t = resolveTemplate($modx, $cmd['template']);
            if (!$t) return ['error' => 'template not found'];
            $existing = $modx->getObject(\MODX\Revolution\modTemplateVarTemplate::class, [
                'tmplvarid'  => $tv->get('id'),
                'templateid' => $t->get('id'),
            ]);
            if ($existing) return ['ok' => true, 'already_assigned' => true];
            $link = $modx->newObject(\MODX\Revolution\modTemplateVarTemplate::class);
            $link->set('tmplvarid', $tv->get('id'));
            $link->set('templateid', $t->get('id'));
            if (!$link->save()) return ['error' => 'save failed'];
            return ['ok' => true, 'assigned' => $cmd['tv'] . ' -> ' . $cmd['template']];

        case 'tv_unassign_template':
            $tv = $modx->getObject(\MODX\Revolution\modTemplateVar::class, ['name' => $cmd['tv']]);
            $t  = resolveTemplate($modx, $cmd['template']);
            if (!$tv || !$t) return ['error' => 'tv or template not found'];
            $link = $modx->getObject(\MODX\Revolution\modTemplateVarTemplate::class, [
                'tmplvarid'  => $tv->get('id'),
                'templateid' => $t->get('id'),
            ]);
            if (!$link) return ['ok' => true, 'was_not_assigned' => true];
            $link->remove();
            return ['ok' => true, 'unassigned' => $cmd['tv'] . ' -> ' . $cmd['template']];

        case 'tv_delete':
            $tv = $modx->getObject(\MODX\Revolution\modTemplateVar::class, ['name' => $cmd['name']]);
            if (!$tv) return ['error' => 'tv not found'];
            $tv->remove();
            return ['ok' => true, 'name' => $cmd['name']];

        case 'tv_setvalue':
            $tv = $modx->getObject(\MODX\Revolution\modTemplateVar::class, ['name' => $cmd['tv']]);
            if (!$tv) return ['error' => 'tv not found'];
            $r = loadResource($modx, $cmd);
            if (!$r) return ['error' => 'resource not found'];
            $value = $cmd['value'];
            if (is_array($value)) $value = json_encode($value, JSON_UNESCAPED_SLASHES);
            $tv->setValue($r->get('id'), $value);
            if (!$tv->save()) return ['error' => 'tv save failed'];
            return ['ok' => true, 'tv' => $cmd['tv'], 'resource' => $r->get('id')];

        // ---------- SNIPPETS -----------------------------------------------
        case 'snippet_list':
            return listElements($modx, \MODX\Revolution\modSnippet::class, 'name');

        case 'snippet_get':
            $s = $modx->getObject(\MODX\Revolution\modSnippet::class, ['name' => $cmd['name']]);
            if (!$s) return ['error' => 'snippet not found'];
            return [
                'id'          => $s->get('id'),
                'name'        => $s->get('name'),
                'description' => $s->get('description'),
                'category'    => $s->get('category'),
                'content'     => $s->get('snippet'),
            ];

        case 'snippet_create':
        case 'snippet_update':
            $s = $modx->getObject(\MODX\Revolution\modSnippet::class, ['name' => $cmd['name']]);
            if (!$s) {
                $s = $modx->newObject(\MODX\Revolution\modSnippet::class);
                $s->set('name', $cmd['name']);
                $created = true;
            } else {
                $created = false;
            }
            if (isset($cmd['content']))     $s->set('snippet', $cmd['content']);
            if (isset($cmd['description'])) $s->set('description', $cmd['description']);
            if (isset($cmd['category']))    $s->set('category', resolveCategoryId($modx, $cmd['category']));
            if (!$s->save()) return ['error' => 'save failed'];
            return ['ok' => true, 'name' => $s->get('name'), 'id' => $s->get('id'), 'created' => $created];

        case 'snippet_delete':
            $s = $modx->getObject(\MODX\Revolution\modSnippet::class, ['name' => $cmd['name']]);
            if (!$s) return ['error' => 'snippet not found'];
            $s->remove();
            return ['ok' => true, 'name' => $cmd['name']];

        // ---------- CATEGORIES ---------------------------------------------
        case 'category_list':
            $out = [];
            foreach ($modx->getIterator(\MODX\Revolution\modCategory::class) as $c) {
                $out[] = ['id' => $c->get('id'), 'category' => $c->get('category'), 'parent' => $c->get('parent')];
            }
            return $out;

        case 'category_create':
            $existing = $modx->getObject(\MODX\Revolution\modCategory::class, ['category' => $cmd['name']]);
            if ($existing) return ['ok' => true, 'id' => $existing->get('id'), 'already_exists' => true];
            $c = $modx->newObject(\MODX\Revolution\modCategory::class);
            $c->set('category', $cmd['name']);
            if (!empty($cmd['parent'])) $c->set('parent', resolveCategoryId($modx, $cmd['parent']));
            if (!$c->save()) return ['error' => 'save failed'];
            return ['ok' => true, 'id' => $c->get('id'), 'name' => $cmd['name']];

        // ---------- MODXTRANSFER SHORTCUTS ---------------------------------
        case 'import_elements':
            $file = MODX_BASE_PATH . ltrim($cmd['file'], '/');
            if (!file_exists($file)) return ['error' => 'file not found: ' . $file];
            $data = json_decode(file_get_contents($file), true);
            if (!is_array($data)) return ['error' => 'invalid json in file'];
            require_once MODX_CORE_PATH . 'components/modxtransfer/model/modxtransfer/modxtransfer.class.php';
            $transfer = new \ModxTransfer($modx);
            return $transfer->getElementsHandler()->import($data, [
                'mode'   => 'execute',
                'update' => $cmd['update'] ?? true,
            ]);

        case 'import_resources':
            $file = MODX_BASE_PATH . ltrim($cmd['file'], '/');
            if (!file_exists($file)) return ['error' => 'file not found: ' . $file];
            $data = json_decode(file_get_contents($file), true);
            if (!is_array($data)) return ['error' => 'invalid json in file'];
            require_once MODX_CORE_PATH . 'components/modxtransfer/model/modxtransfer/modxtransfer.class.php';
            $transfer = new \ModxTransfer($modx);
            return $transfer->getResourcesHandler()->import($data, [
                'mode'     => 'execute',
                'update'   => $cmd['update'] ?? true,
                'parentId' => (int) ($cmd['parentId'] ?? 0),
            ]);

        default:
            return ['error' => 'unknown action: ' . $action];
    }
}

// ===========================================================================
// Helpers
// ===========================================================================

function loadResource(\MODX\Revolution\modX $modx, array $cmd)
{
    if (!empty($cmd['id'])) {
        return $modx->getObject(\MODX\Revolution\modResource::class, (int) $cmd['id']);
    }
    if (!empty($cmd['alias'])) {
        return $modx->getObject(\MODX\Revolution\modResource::class, [
            'alias'       => $cmd['alias'],
            'context_key' => $cmd['context'] ?? 'web',
        ]);
    }
    return null;
}

// -----------------------------------------------------------------------------
// briefResource / fullResource field exposure
//
// All fields exposed below are core MODX Revolution modResource columns that
// exist on every 2.x / 3.x install, regardless of which extras are present.
// The bridge is intentionally agnostic of third-party extras like Collections,
// Articles, etc. It never assumes any extra is installed and never fails if
// one is missing. Consumers can inspect `class_key` to detect extras such as
// `Collections\Model\CollectionContainer` on parents and decide how to behave.
// -----------------------------------------------------------------------------
function briefResource(\MODX\Revolution\modX $modx, \MODX\Revolution\modResource $r): array
{
    return [
        'id'           => $r->get('id'),
        'pagetitle'    => $r->get('pagetitle'),
        'alias'        => $r->get('alias'),
        'parent'       => $r->get('parent'),
        'template'     => $r->get('template'),
        'class_key'    => $r->get('class_key'),
        'published'    => (bool) $r->get('published'),
        'show_in_tree' => (int) $r->get('show_in_tree'),
        'menuindex'    => (int) $r->get('menuindex'),
    ];
}

function fullResource(\MODX\Revolution\modX $modx, \MODX\Revolution\modResource $r, bool $includeContent): array
{
    $data = [
        'id'            => $r->get('id'),
        'pagetitle'     => $r->get('pagetitle'),
        'longtitle'     => $r->get('longtitle'),
        'alias'         => $r->get('alias'),
        'description'   => $r->get('description'),
        'introtext'     => $r->get('introtext'),
        'menutitle'     => $r->get('menutitle'),
        'parent'        => $r->get('parent'),
        'template'      => $r->get('template'),
        'class_key'     => $r->get('class_key'),
        'context_key'   => $r->get('context_key'),
        'content_type'  => $r->get('content_type'),
        'content_dispo' => $r->get('content_dispo'),
        'published'     => (bool) $r->get('published'),
        'publishedon'   => $r->get('publishedon'),
        'pub_date'      => $r->get('pub_date'),
        'unpub_date'    => $r->get('unpub_date'),
        'hidemenu'      => (bool) $r->get('hidemenu'),
        'show_in_tree'  => (int) $r->get('show_in_tree'),
        'searchable'    => (bool) $r->get('searchable'),
        'deleted'       => (bool) $r->get('deleted'),
        'menuindex'     => (int) $r->get('menuindex'),
        'uri'           => $r->get('uri'),
        'createdon'     => $r->get('createdon'),
        'createdby'     => $r->get('createdby'),
        'editedon'      => $r->get('editedon'),
        'editedby'      => $r->get('editedby'),
    ];
    if ($includeContent) {
        $data['content'] = $r->get('content');
    }
    $tvs = [];
    foreach ($r->getTemplateVars() as $tv) {
        $tvs[$tv->get('name')] = $tv->getValue($r->get('id'));
    }
    $data['tvs'] = $tvs;
    return $data;
}

function applyResourceFields(\MODX\Revolution\modX $modx, \MODX\Revolution\modResource $r, array $fields): void
{
    foreach ($fields as $key => $value) {
        if ($key === 'template' && !is_numeric($value)) {
            $t = resolveTemplate($modx, $value);
            if ($t) $r->set('template', $t->get('id'));
            continue;
        }
        $r->set($key, $value);
    }
}

function setResourceTvs(\MODX\Revolution\modX $modx, \MODX\Revolution\modResource $r, array $tvs): void
{
    foreach ($tvs as $tvName => $value) {
        $tv = $modx->getObject(\MODX\Revolution\modTemplateVar::class, ['name' => $tvName]);
        if (!$tv) continue;
        if (is_array($value)) $value = json_encode($value, JSON_UNESCAPED_SLASHES);
        $tv->setValue($r->get('id'), $value);
        $tv->save();
    }
}

function resolveTemplate(\MODX\Revolution\modX $modx, $ref)
{
    if (is_numeric($ref)) {
        return $modx->getObject(\MODX\Revolution\modTemplate::class, (int) $ref);
    }
    return $modx->getObject(\MODX\Revolution\modTemplate::class, ['templatename' => $ref]);
}

function resolveCategoryId(\MODX\Revolution\modX $modx, $ref): int
{
    if (is_numeric($ref)) return (int) $ref;
    if (empty($ref)) return 0;
    $c = $modx->getObject(\MODX\Revolution\modCategory::class, ['category' => $ref]);
    return $c ? (int) $c->get('id') : 0;
}

function chunkToArray(\MODX\Revolution\modX $modx, \MODX\Revolution\modChunk $c): array
{
    return [
        'id'          => $c->get('id'),
        'name'        => $c->get('name'),
        'description' => $c->get('description'),
        'category'    => $c->get('category'),
        'content'     => $c->get('snippet'),
    ];
}

function listElements(\MODX\Revolution\modX $modx, string $class, string $nameField): array
{
    $out = [];
    foreach ($modx->getIterator($class) as $el) {
        $out[] = [
            'id'          => $el->get('id'),
            'name'        => $el->get($nameField),
            'description' => $el->get('description'),
            'category'    => $el->get('category'),
        ];
    }
    return $out;
}
