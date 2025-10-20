import { promises as fs } from 'fs';
import path from 'path';

export type VerifyRepoPaths = {
  repoPath: string;
  chainId: number;
};

export type RepoMatch = {
  type: 'full' | 'partial';
  dir: string;
};

export async function findRepoMatch({ repoPath, chainId }: VerifyRepoPaths, address: string): Promise<RepoMatch | null> {
  const addr = address.toLowerCase();
  const full = path.join(repoPath, 'contracts', 'full_match', String(chainId), addr);
  const partial = path.join(repoPath, 'contracts', 'partial_match', String(chainId), addr);
  try {
    const st = await fs.stat(full);
    if (st.isDirectory()) return { type: 'full', dir: full };
  } catch {}
  try {
    const st = await fs.stat(partial);
    if (st.isDirectory()) return { type: 'partial', dir: partial };
  } catch {}
  return null;
}

export async function readMetadata(dir: string) {
  const m = path.join(dir, 'metadata.json');
  const data = await fs.readFile(m, 'utf8');
  return JSON.parse(data);
}

export async function listSources(dir: string): Promise<Array<{ path: string; content: string }>> {
  const srcDir = path.join(dir, 'sources');
  const out: Array<{ path: string; content: string }> = [];
  async function walk(rel: string) {
    const abs = path.join(srcDir, rel);
    const entries = await fs.readdir(abs, { withFileTypes: true }).catch(() => [] as any);
    for (const e of entries) {
      const pRel = path.join(rel, e.name);
      const pAbs = path.join(srcDir, pRel);
      if (e.isDirectory()) {
        await walk(pRel);
      } else if (e.isFile()) {
        const content = await fs.readFile(pAbs, 'utf8').catch(() => '');
        out.push({ path: pRel, content });
      }
    }
  }
  try { await walk(''); } catch {}
  return out;
}
