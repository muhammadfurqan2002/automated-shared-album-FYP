const jwt = require('jsonwebtoken');
const secretKey = process.env.JWT_SECRET || '12345';
function authenticateJWT(req, res, next) {
  const authHeader = req.headers.authorization;
  console.log(req.user);
  console.log(authHeader);
  if (authHeader) {
    const token = authHeader.split(' ')[1];
    console.log(token);
  
    jwt.verify(token, secretKey, (err, decoded) => {
      if (err) {
        return res.status(403).json({ error: 'Forbidden: Invalid token.' });
      }
      req.user = decoded;
      console.log(req.user);
      next();
    });
  } else {
    return res.status(401).json({ error: 'Unauthorized: No token provided.' });
  }
}

module.exports = { authenticateJWT };