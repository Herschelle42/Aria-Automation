To move an action via the API.

specify the new location in the `module` parameter. in the example below we are moving the action `testActionMove` to `dev.actions`

```
PUT /actions/{id}
```
body
```json
{ 
    "name": "testActionMove",
    "module": "dev.actions" 
}
```

The swagger page (/vco/api/docs/swagger-ui/index.html#/Actions%20Service/updateAction) does not give any examples of updates you can do on an action. 

`name` and `module` appear to be the only mandatory items within the body even if not moving the actions location
