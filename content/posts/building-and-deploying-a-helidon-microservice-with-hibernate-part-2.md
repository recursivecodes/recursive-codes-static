---
title: "Building And Deploying A Helidon Microservice With Hibernate Part 2"
slug: "building-and-deploying-a-helidon-microservice-with-hibernate-part-2"
author: "Todd Sharp"
date: 2019-07-08
summary: "In this post we'll build the model and our logic for persisting user objects. We'll also compile and test the microservice for the first time."
tags: ["Cloud", "Containers, Microservices, APIs", "Developers", "Java"]
keywords: "microservices, Java, Cloud"
featuredimage: "https://objectstorage.us-ashburn-1.oraclecloud.com/n/idatzojkinhi/b/img.recursive.codes/o/71146ab3-c377-47c5-a830-18f483f0a572/banner_nghia_le_v3dokm1nqcs_unsplash.jpg"
---

So far in this series, we've [set up our cloud for Kubernetes and Docker](/posts/the-complete-guide-to-getting-up-and-running-with-docker-and-kubernetes-on-the-oracle-cloud), got our [Autonomous DB up and running](/posts/the-complete-guide-to-getting-up-and-running-with-autonomous-database-in-the-cloud) and [created our first microservice using Helidon and Hibernate](/posts/building-and-deploying-a-helidon-microservice-with-hibernate-part-1). We're now ready to move on to creating the data model and persistence logic for our first microservice that will persist user data for our fictional social media application. If you're new to this series, I recommend catching up on the previous posts linked above so that you can follow along more easily as we move forward in the series.

Note: All of the code for this series is [available on GitHub](https://github.com/cloud-native-microservices).

So our user microservice application has been configured and we're ready to create our model that represents our user objects. Create a new package called `model` and within that a class called `User.java`. We'll add properties that map to our database columns and some validation constraints to ensure our data is valid before we try to persist it. If you recall, our table was created with the following DDL script:

<div>
```sql
CREATE TABLE users(
  "ID" VARCHAR2(32 BYTE) DEFAULT ON NULL SYS_GUID(), 
  "FIRST_NAME" VARCHAR2(50 BYTE) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
  "LAST_NAME" VARCHAR2(50 BYTE) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
  "USERNAME" VARCHAR2(50 BYTE) COLLATE "USING_NLS_COMP" NOT NULL ENABLE, 
  "CREATED_ON" TIMESTAMP (6) DEFAULT ON NULL CURRENT_TIMESTAMP, 
  CONSTRAINT "USER_PK" PRIMARY KEY ("ID")
);
```



</div>

So our `User` object will need 5 properties: `id`, `firstName`, `lastName`, `username` and `createdOn`. The `firstName`, `lastName` and `username` properties are non-nullable strings that have a max length of 50 characters. The `ID` property will be a GUID and the `createdOn` property is a timestamp. With that in mind, our properties and validation annotations on the User object will look like so:
```java
@Id
@GeneratedValue(strategy = GenerationType.IDENTITY, generator = "system-uuid")
@GenericGenerator(name = "system-uuid", strategy = "guid")
@Column(name = "id", unique = true, nullable = false)
private String id;

@Column(name = "first_name")
@NotNull
@Size(max=50)
private String firstName;

@Column(name = "last_name")
@NotNull
@Size(max=50)
private String lastName;

@Column(name = "username")
@NotNull
@Size(max=50)
private String username;

@JsonFormat(shape = JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss.SSSXXX")
@Column(name = "created_on")
private Date createdOn = new Date();
```



The [rest of the User object](https://github.com/cloud-native-microservices/user-svc-helidon-hibnernate/blob/master/src/main/java/codes/recursive/cnms/user/model/User.java) is standard boilerplate - nothing complicated. 

The next step is to create a repository for our service persistence operations. Create a class in our `user` package called `UserRepository.java.` 
```java
@RequestScoped
public class UserRepository {
}
```



We'll inject our UserProvider that we created in the last post of this series to get our configuration into the repository and create our entity manager in the constructor:
```java
@RequestScoped
public class UserRepository {
    @PersistenceContext
    private static EntityManager entityManager;

    @Inject
    public UserRepository(UserProvider userProvider) {
        Map<String, Object> configOverrides = new HashMap<String, Object>();
        configOverrides.put("hibernate.connection.url", userProvider.getDbUrl());
        configOverrides.put("hibernate.connection.username", userProvider.getDbUser());
        configOverrides.put("hibernate.connection.password", userProvider.getDbPassword());
        EntityManagerFactory emf = Persistence.createEntityManagerFactory("UserPU", configOverrides);
        entityManager = emf.createEntityManager();
    }
}
```



Now add a `validate()` method that we can use to make sure our users are valid before we try to save them.
```java
public Set<ConstraintViolation<User>> validate(User user) {
    Validator validator = Validation.buildDefaultValidatorFactory().getValidator();
    Set<ConstraintViolation<User>> constraintViolations = validator.validate(user);
    return constraintViolations;
}
```



We'll finish off the repository by adding methods for `save()`, `get()`, `findAll()`, `count()` and `deleteById()`. They're pretty standard CRUD methods, so I'll post them without explanation:
```java
public User save(User user) {
    entityManager.getTransaction().begin();
    entityManager.persist(user);
    entityManager.getTransaction().commit();
    return user;
}

public User get(String id) {
    User user = entityManager.find(User.class, id);
    return user;
}

public List<User> findAll() {
    return entityManager.createQuery("from User").getResultList();
}

public List<User> findAll(int offset, int max) {
    Query query = entityManager.createQuery("from User");
    query.setFirstResult(offset);
    query.setMaxResults(max);
    return query.getResultList();
}

public long count() {
    Query queryTotal = entityManager.createQuery("Select count(u.id) from User u");
    long countResult = (long)queryTotal.getSingleResult();
    return countResult;
}

public void deleteById(String id) {
    // Retrieve the movie with this ID
    User user = get(id);
    if (user != null) {
        try {
            entityManager.getTransaction().begin();
            entityManager.remove(user);
            entityManager.getTransaction().commit();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```



Next, modify or replace `GreetResource` with `UserResource`. The resource file is where you define your service endpoints in Helidon. Start the resource out like so:
```java
@Path("/user")
@RequestScoped
public class UserResource {
}
```



This tells Helidon to listen on the path of `/users` for all methods in this class. We'll further define the path with each method. Before we get to the methods though, add a constructor where we'll use `@Inject` to get an instance of our `UserRepository`:
```java
@Inject
public UserResource(UserRepository userRepository) {
    this.userRepository = userRepository;
}
```



Now we can add paths to the resource. To define a default path, simply omit the `@Path` annotation on the method. This will be called whenever `http://localhost:8080/user` is called:
```java
@GET
@Produces(MediaType.APPLICATION_JSON)
public Response getDefaultMessage() {
    return Response.ok(Map.of("OK", true)).build();
}
```



So defining each CRUD operation is a matter of creating resource methods and calling the appropriate repository methods.

To get a user by ID:
```java
@Path("/{id}")
@GET
@Produces(MediaType.APPLICATION_JSON)
public Response getById(@PathParam("id") String id) {
    User user = userRepository.get(id);
    if( user != null ) {
        return Response.ok(user).build();
    }
    else {
        return Response.status(404).build();
    }
}
```



To list users:
```java
@Path("/list")
@GET
@Produces(MediaType.APPLICATION_JSON)
public Response getAllUsers() {
    return Response.ok(this.userRepository.findAll()).build();
}
```



To list users with pagination:
```java
@Path("/list/{offset}/{max}")
@GET
@Produces(MediaType.APPLICATION_JSON)
public Response getAllUsersPaginated(@PathParam("offset") int offset, @PathParam("max") int max) {
    return Response.ok(this.userRepository.findAll(offset, max)).build();
}
```



To delete a user by ID:
```java
@Path("/list/{offset}/{max}")
@GET
@Produces(MediaType.APPLICATION_JSON)
public Response getAllUsersPaginated(@PathParam("offset") int offset, @PathParam("max") int max) {
    return Response.ok(this.userRepository.findAll(offset, max)).build();
}
```



And finally, to save a user (note that we call `validate()` before attempting the save, returning validation errors with a 422 Unprocessable Entity status if there are any):
```java
@Path("/save")
@POST
@Produces(MediaType.APPLICATION_JSON)
public Response saveUser(User user) {
    Set<ConstraintViolation<User>> violations = userRepository.validate(user);

    if( violations.size() == 0 ) {
        userRepository.save(user);
        return Response.created(
                uriInfo.getBaseUriBuilder()
                        .path("/user/{id}")
                        .build(user.getId())
        ).build();
    }
    else {
        List<HashMap<String, String>> errors = new ArrayList<>();

        violations.stream()
                .forEach( (violation) -> {
                            Object invalidValue = violation.getInvalidValue();
                            HashMap<String, String> errorMap = new HashMap<>();
                            errorMap.put("field", violation.getPropertyPath().toString());
                            errorMap.put("message", violation.getMessage());
                            errorMap.put("currentValue", invalidValue == null ? null : invalidValue.toString());
                            errors.add(errorMap);
                        }
                );

        return Response.status(422)
                .entity(Map.of( "validationErrors", errors ))
                .build();
    }

}
```



We're now ready to compile and test our endpoints. Compile the service with `mvn package` and then run the application with the following command. We need to pass in some properties here so the configuration is set properly, so refer to the previous post if you need to recall the path to your wallet files or the schema username or password. Substitute the path and credentials as appropriate:
```bash
java 
    -Doracle.net.wallet_location=/path/to/wallet \
    -Doracle.net.authentication_services="(TCPS)" \
    -Doracle.net.tns_admin=/wallet-demodb \
    -Djavax.net.ssl.trustStore=/path/to/wallet/cwallet.sso \
    -Djavax.net.ssl.trustStoreType=SSO \
    -Djavax.net.ssl.keyStore=/path/to/wallet/cwallet.sso \
    -Djavax.net.ssl.keyStoreType=SSO \
    -Doracle.net.ssl_server_dn_match=true \
    -Doracle.net.ssl_version="1.2" \
    -Ddatasource.username=[username] \
    -Ddatasource.password=[password] \
    -Ddatasource.url=jdbc:oracle:thin:@demodb_LOW?TNS_ADMIN=/path/to/wallet \
-jar target/user-svc.jar
```



Your app should now be up and running on port 8080 of your localhost. We can test out the endpoints like so at this point:

Get User Service Endpoint (returns 200 OK):
```bash
curl -iX GET http://localhost:8080/user                                                                                                                                                    
HTTP/1.1 200 OK
Content-Type: application/json
Date: Thu, 20 Jun 2019 10:35:06 -0400
transfer-encoding: chunked
connection: keep-alive
{"OK":true}
```



Save a new user (ID is returned in \`Location\` header):
```bash
curl -iX POST -H "Content-Type: application/json" -d '{"firstName": "Todd", "lastName": "Sharp", "username": "recursivecodes"}' http://localhost:8080/user/save                            
HTTP/1.1 201 Created
Date: Thu, 20 Jun 2019 10:45:38 -0400
Location: http://[0:0:0:0:0:0:0:1]:8080/user/8BC3669097C9EC53E0532110000A6E11
transfer-encoding: chunked
connection: keep-alive
```



Save a new user with invalid data (will return 422 and validation errors):
```bash
curl -iX POST -H "Content-Type: application/json" -d '{"firstName": "A Really Long First Name That Will Be Longer Than 50 Chars", "lastName": null, "username": null}' http://localhost:8080/user/save                            
HTTP/1.1 422 Unprocessable Entity
Content-Type: application/json
Date: Mon, 1 Jul 2019 11:21:57 -0400
transfer-encoding: chunked
connection: keep-alive

{"validationErrors":[{"field":"username","message":"may not be null","currentValue":null},{"field":"lastName","message":"may not be null","currentValue":null},{"field":"firstName","message":"size must be between 0 and 50","currentValue":"A Really Long First Name That Will Be Longer Than 50 Chars"}]}
```



Get the new user:
```bash
curl -iX GET http://localhost:8080/user/8BC3669097C9EC53E0532110000A6E11                                                                                                                   
HTTP/1.1 200 OK
Content-Type: application/json
Date: Thu, 20 Jun 2019 10:46:17 -0400
transfer-encoding: chunked
connection: keep-alive

{"id":"8BC3669097C9EC53E0532110000A6E11","firstName":"Todd","lastName":"Sharp","username":"recursivecodes","createdOn":"2019-06-20T14:45:38.509Z"}
```



List all users:
```bash
curl -iX GET http://localhost:8080/user/list                                                                                                                                               
HTTP/1.1 200 OK
Content-Type: application/json
Date: Thu, 20 Jun 2019 10:46:51 -0400
transfer-encoding: chunked
connection: keep-alive

[{"id":"8BC3669097C9EC53E0532110000A6E11","firstName":"Todd","lastName":"Sharp","username":"recursivecodes","createdOn":"2019-06-20T14:45:38.509Z"}]
```



Delete a user
```bash
curl -iX DELETE http://localhost:8080/user/8BC3669097C9EC53E0532110000A6E11                                                                                                                
HTTP/1.1 204 No Content
Date: Thu, 20 Jun 2019 10:47:21 -0400
connection: keep-alive
```



Confirm delete (same GET by ID will return 404)
```bash
curl -iX GET http://localhost:8080/user/8BC3669097C9EC53E0532110000A6E11                                                                                                                   
HTTP/1.1 404 Not Found
Date: Thu, 20 Jun 2019 10:47:43 -0400
transfer-encoding: chunked
connection: keep-alive
```



And you've now created your first microservice using Helidon and Hibernate! In the next post we'll look at deploying the service to Docker and Kubernetes.

[Photo by ][Nghia Le](https://unsplash.com/@lephunghia?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)[ on ][Unsplash](https://unsplash.com/search/photos/happy?utm_source=unsplash&utm_medium=referral&utm_content=creditCopyText)
