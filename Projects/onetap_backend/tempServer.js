const express=require('express');
const app=express();
app.get('/api/groups/mes-groupes/:userId',(req,res)=>res.end('ok'));
const server=app.listen(3001,()=>console.log('ok'));
