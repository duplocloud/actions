# Migration  

This specific directory has been moved to the root of the repository. Therefore, the path to the action has changed and this specific action is now located at `duplocloud/actions`. We will only teporarily maintain the current location for backwards compatibility.

Change the following: 
```yaml
- name: Setup
  uses: duplocloud/actions/setup@main
```
To be: 
```yaml
- name: Setup
  uses: duplocloud/actions@main
```

New location: [../README.md](../README.md)
