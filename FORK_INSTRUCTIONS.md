# Instructions to Fix Linker Errors in PR 2752

The PR 2752 branch has missing event implementations. To fix this, you need to fork ZMK and add the missing files.

## Step 1: Fork ZMK

1. Go to https://github.com/zmkfirmware/zmk
2. Click "Fork" to create your own fork
3. Note your GitHub username (e.g., `piontec`)

## Step 2: Create a Branch Based on PR 2752

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/zmk.git
cd zmk

# Fetch the PR
git fetch origin pull/2752/head:pr2752

# Create a branch from the PR
git checkout -b pr2752-patched pr2752
```

## Step 3: Add Missing Event Files

Copy the files from `patches/` directory:

```bash
# From your zmk-sofle repository
cp patches/split_peripheral_layer_changed.h zmk/app/include/zmk/events/
cp patches/split_peripheral_layer_changed.c zmk/app/src/events/

# Ensure hid_indicators_changed.c exists (it should, but verify)
# If missing, copy patches/hid_indicators_changed.c to zmk/app/src/events/
```

## Step 4: Commit and Push

```bash
cd zmk
git add app/include/zmk/events/split_peripheral_layer_changed.h
git add app/src/events/split_peripheral_layer_changed.c
git commit -m "Add missing event implementations for PR 2752

- Add zmk_split_peripheral_layer_changed event
- Ensure zmk_hid_indicators_changed event is implemented
- Fixes linker errors in behavior_underglow_indicators and activity modules"
git push origin pr2752-patched
```

## Step 5: Update west.yml

Update `config/west.yml` to use your fork:

```yaml
- name: zmk
  remote: zmkfirmware
  revision: pr2752-patched  # Your branch name
  url: https://github.com/YOUR_USERNAME/zmk  # Your fork URL
  import: app/west.yml
```

Or if using a different remote:

```yaml
manifest:
  remotes:
    - name: zmkfirmware
      url-base: https://github.com/zmkfirmware
    - name: yourusername
      url-base: https://github.com/YOUR_USERNAME
  projects:
    - name: zmk
      remote: yourusername
      revision: pr2752-patched
      import: app/west.yml
```

## Step 6: Test

Push your changes and let GitHub Actions build. The linker errors should be resolved.

